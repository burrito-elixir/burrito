defmodule Burrito.Steps.Patch.RecompileNIFs do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Log
  alias Burrito.Builder.Step
  alias Burrito.Builder.Target

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    cflags = Keyword.get(context.target.qualifiers, :nif_cflags, "")
    cxxflags = Keyword.get(context.target.qualifiers, :nif_cxxflags, "")
    nif_env = Keyword.get(context.target.qualifiers, :nif_env, [])
    nif_make_args = Keyword.get(context.target.qualifiers, :nif_make_args, [])
    skip_nifs? = Keyword.get(context.target.qualifiers, :skip_nifs, false)

    if context.target.cross_build and not skip_nifs? do
      triplet = Target.make_triplet(context.target)

      {:local_unpacked, path: erts_location} = context.target.erts_source

      nif_sniff()
      |> Enum.each(fn dep ->
        maybe_recompile_nif(dep, context.work_dir, erts_location, triplet, cflags, cxxflags, nif_env, nif_make_args)
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

  defp maybe_recompile_nif({_, _, false}, _, _, _, _, _, _, _), do: :no_nif

  defp maybe_recompile_nif(
         {dep, path, true},
         release_working_path,
         erts_path,
         cross_target,
         extra_cflags,
         extra_cxxflags,
         extra_env,
         extra_make_args
       ) do
    dep = Atom.to_string(dep)

    Log.info(:step, "Going to recompile NIF for cross-build: #{dep} -> #{cross_target}")

    output_priv_dir =
      Path.join(release_working_path, ["lib/#{dep}*/"])
      |> Path.expand()
      |> Path.wildcard()
      |> List.first()

    _ = System.cmd("make", ["clean"], cd: path, stderr_to_stdout: true, into: IO.stream())

    # Compose env variables for cross-compilation, if we're building for linux, force dynamic linking
    erts_env =
      if String.contains?(cross_target, "linux") do
        erts_make_env(erts_path) ++ [{"LDFLAGS", "-dynamic-linker /dev/null"}]
      else
        erts_make_env(erts_path)
      end

    # This currently is only designed for elixir_make NIFs
    build_result =
      System.cmd("make", ["all", "--always-make"] ++ extra_make_args,
        cd: path,
        stderr_to_stdout: true,
        env:
          [
            {"MIX_APP_PATH", output_priv_dir},
            {"RANLIB", "zig ranlib"},
            {"AR", "zig ar"},
            {"CC",
             "zig cc -target #{cross_target} -O2 -dynamic -shared -Wl,-undefined=dynamic_lookup #{extra_cflags}"},
            {"CXX",
             "zig c++ -target #{cross_target} -O2 -dynamic -shared -Wl,-undefined=dynamic_lookup #{extra_cxxflags}"}
          ] ++ erts_env ++ extra_env,
        into: IO.stream()
      )

    case build_result do
      {_, 0} ->
        Log.info(:step, "Successfully re-built #{dep} for #{cross_target}!")

        src_priv_files =
          Path.join(output_priv_dir, ["priv/*"]) |> Path.expand() |> Path.wildcard()

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
