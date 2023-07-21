defmodule Burrito.Steps.Patch.RecompileNIFs do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Log
  alias Burrito.Builder.Step
  alias Burrito.Builder.Target

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    # TODO: Nifs can only be re-compiled if Zig is present.
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

    output_priv_dir =
      Path.join(release_working_path, ["lib/#{dep}*/"])
      |> Path.expand()
      |> Path.wildcard()
      |> List.first()

    _ = System.cmd("make", ["clean"], cd: path, stderr_to_stdout: true, into: IO.stream())

    erts_env = erts_make_env(erts_path)

    # This currently is only designed for elixir_make NIFs
    build_result =
      System.cmd("make", ["all", "--always-make"],
        cd: path,
        stderr_to_stdout: true,
        env: [
          {"MIX_APP_PATH", output_priv_dir},
          {"RANLIB", "zig ranlib"},
          {"AR", "zig ar"},
          {"CC",
           "zig cc -target #{cross_target} -shared -Wl,-undefined=dynamic_lookup"},
          {"CXX",
           "zig c++ -target #{cross_target} -shared -Wl,-undefined=dynamic_lookup"}
        ] ++ erts_env,
        into: IO.stream()
      )

    case build_result do
      {_, 0} ->
        Log.info(:step, "Successfully re-built #{dep} for #{cross_target}!")

        src_priv_files = Path.join(output_priv_dir, ["priv/*"]) |> Path.expand() |> Path.wildcard()

        final_output_priv_dir = Path.join(output_priv_dir, "priv")

        Enum.each(src_priv_files, fn file ->
          file_name = Path.basename(file)
          if Path.extname(file_name) == ".so" && String.contains?(cross_target, "windows") do
            new_file_name = String.replace_trailing(file_name, ".so", ".dll")
            dst_fullpath = Path.join(final_output_priv_dir, new_file_name)

            Log.info(:step, "#{file} -> #{dst_fullpath}")

            File.rename!(file, dst_fullpath)
          else
            file_name
          end
        end)

      {output, _} ->
        Log.error(:step, "Failed to rebuild #{dep} for #{cross_target}!")
        Log.error(:step, output)
        exit(1)
    end
  end

  defp erts_make_env(erts_path) do
    ei_include =
      Path.join(erts_path, ["otp*/", "usr/", "include/"])
      |> Path.expand()
      |> Path.wildcard()
      |> List.first()

    ei_lib =
      Path.join(erts_path, ["otp*/", "usr/", "lib/"])
      |> Path.expand()
      |> Path.wildcard()
      |> List.first()

    erts_include =
      Path.join(erts_path, ["otp*/", "erts*/", "include/"])
      |> Path.expand()
      |> Path.wildcard()
      |> List.first()

    [
      {"ERL_EI_INCLUDE_DIR", ei_include},
      {"ERL_EI_LIBDIR", ei_lib},
      {"ERL_INTERFACE_INCLUDE_DIR", ei_include},
      {"ERL_INTERFACE_LIB_DIR", ei_lib},
      {"ERTS_INCLUDE_DIR", erts_include}
    ]
  end
end
