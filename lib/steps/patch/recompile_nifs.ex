defmodule Burrito.Steps.Patch.RecompileNIFs do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Log
  alias Burrito.Builder.Step
  alias Burrito.Builder.Target

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    if context.target.cross_build do
      triplet = Target.make_triplet(context.target)

      {:local_unpacked, path: erts_location} = context.target.erts_source

      nif_sniff()
      |> Enum.each(fn dep ->
        maybe_recompile_nif(dep, context.work_dir, erts_location, triplet)
      end)
    end

    context
  end

  def nif_sniff() do
    # The current procedure for finding out if a dependency has a NIF:
    # - List all deps in the project using Mix.Project.deps_paths/0
    #   - Iterate over those, and use Mix.Project.in_project/4 to execute a function inside their project context
    #   - Check if they contain :elixir_make in their `:compilers`
    #
    # We'll probably need to expand how we detect NIFs, but :elixir_make is a popular way to compile NIFs
    # so it's a good place to start...

    paths = Mix.Project.deps_paths() |> Enum.filter(fn {name, _} -> name != :burrito end)

    Enum.map(paths, fn {dep_name, path} ->
      Mix.Project.in_project(dep_name, path, fn module ->
        if module && Keyword.has_key?(module.project, :compilers) do
          {dep_name, path, Enum.member?(module.project[:compilers], :elixir_make)}
        else
          {dep_name, path, false}
        end
      end)
    end)
  end

  defp maybe_recompile_nif({_, _, false}, _, _, _), do: :no_nif

  defp maybe_recompile_nif(
         {dep, path, true},
         release_working_path,
         erts_path,
         cross_target
       ) do
    dep = Atom.to_string(dep)

    Log.info(:step, "Going to recompile NIF for cross-build: #{dep} -> #{cross_target}")

    _ = System.cmd("make", ["clean"], cd: path, stderr_to_stdout: true, into: IO.stream())

    erts_include =
      Path.join(erts_path, ["otp-*/", "erts*/", "/include"]) |> Path.wildcard() |> List.first()

    build_result =
      System.cmd("make", ["--always-make"],
        cd: path,
        stderr_to_stdout: true,
        env: [
          {"RANLIB", "zig ranlib"},
          {"AR", "zig ar"},
          {"CC", "zig cc -target #{cross_target} -v -shared -Wl,-undefined=dynamic_lookup"},
          {"CXX", "zig c++ -target #{cross_target} -v -shared -Wl,-undefined=dynamic_lookup"},
          {"CXXFLAGS", "-I#{erts_include}"},
          {"CFLAGS", "-I#{erts_include}"}
        ],
        into: IO.stream()
      )

    case build_result do
      {_, 0} ->
        Log.info(:step, "Successfully re-built #{dep} for #{cross_target}!")

        src_priv_files = Path.join(path, ["priv/*"]) |> Path.wildcard()

        output_priv_dir =
          Path.join(release_working_path, ["lib/#{dep}*/priv"]) |> Path.wildcard() |> List.first()

        Enum.each(src_priv_files, fn file ->
          file_name = Path.basename(file)
          dst_fullpath = Path.join(output_priv_dir, file_name)

          Log.info(:step, "#{file} -> #{output_priv_dir}")

          File.copy!(file, dst_fullpath)
        end)

      {output, _} ->
        Log.error(:step, "Failed to rebuild #{dep} for #{cross_target}!")
        Log.error(:step, output)
        exit(1)
    end
  end
end
