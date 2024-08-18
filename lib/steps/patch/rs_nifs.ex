defmodule Burrito.Steps.Patch.RsNifs do
  @moduledoc """
  This Step module is responsible for finding (sniffing) for Rust (rustler) based NIFs.
  If the NIF is using rustler_precompiled, it will override the target.

  (NOTE: We currently only have rustler_precompiled support!)
  There are plans in place to 
  """

  alias Burrito.Builder.Context
  alias Burrito.Builder.Log
  alias Burrito.Builder.Step
  alias Burrito.Builder.Target

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    skip_nifs? = Keyword.get(context.target.qualifiers, :skip_nifs, false)
    cross_target = Target.make_triplet(context.target)

    if context.target.cross_build and not skip_nifs? do
      shell = Mix.shell()
      Mix.shell(Mix.Shell.Quiet)
      potential_nifs = niff_sniff()

      Enum.each(potential_nifs, fn {name, path} ->
        IO.inspect(path)

        Log.info(
          :step,
          "⚙️ Going to rebuild rustler_precompiled NIF dep: #{name} -> #{cross_target}"
        )

        env =
          [
            {"TARGET_OS", Atom.to_string(context.target.os)},
            {"TARGET_ABI", get_abi(context.target)},
            {"TARGET_CPU", Atom.to_string(context.target.cpu)}
          ] ++ Map.to_list(System.get_env())

        Mix.shell().cmd(
          "mix deps.compile #{Atom.to_string(name)} --force",
          env: env
        )

        Log.success(:step, "Rebuilt #{name} for #{cross_target}!")

        # Copy over the re-built dep into the release working dir
        dep_def = Mix.Dep.cached() |> Enum.find(fn dep -> dep.app == name end)
        src_dir = dep_def.opts |> Keyword.get(:build)

        dest_dir =
          Path.join(context.work_dir, ["lib/#{name}*/"])
          |> Path.expand()
          |> Path.wildcard()
          |> List.first()

        Log.warning(
          :step,
          "Reinstalling rustler_precompiled NIF #{name} #{src_dir} -> #{dest_dir}"
        )

        File.rm_rf!(dest_dir)
        File.cp_r!(src_dir, dest_dir)
        
        # This basically restores the dep back to the host's configurations
        # it's nice to do this because otherwise, if the user goes to debug/run their
        # app after building, it'll have the wrong NIF binary downloaded, and that's confusing.
        Mix.shell().cmd("mix deps.compile #{Atom.to_string(name)} --force")

        Log.success(:step, "Done reinstalling rustler_precompiled NIF #{name}!")
      end)

      Mix.shell(shell)
    end

    context
  end

  defp get_abi(%Target{os: :windows}), do: "msvc"
  defp get_abi(%Target{os: :darwin}), do: ""
  defp get_abi(%Target{os: :linux}), do: "musl"

  defp niff_sniff() do
    paths =
      Mix.Project.deps_paths()
      |> Enum.filter(fn {name, _} -> name != :burrito and name != :rustler_precompiled end)

    # This finds all deps that have rustler or rustler_precompiled
    deps =
      Enum.map(paths, fn {dep_name, path} ->
        Mix.Project.in_project(dep_name, path, fn module ->
          if module && Keyword.has_key?(module.project, :deps) do
            found_rustler_precompiled = find_dep(module, :rustler_precompiled)
            found_rustler = find_dep(module, :rustler)

            {dep_name, path,
             rustler: found_rustler != nil, rustler_precompiled: found_rustler_precompiled != nil}
          else
            {dep_name, path, [rustler: false, rustler_precompiled: false]}
          end
        end)
      end)

    # Filter out NIFs we don't support/don't care about
    Enum.reduce(deps, [], fn dep, acc ->
      {name, path, [rustler: rustler?, rustler_precompiled: rustler_precompiled?]} = dep

      cond do
        rustler? and rustler_precompiled? ->
          Log.success(:step, "Found precompiled Rustler NIF to replace! (#{name})")
          [{name, path} | acc]

        rustler_precompiled? and not rustler? ->
          [{name, path} | acc]

        rustler? and not rustler_precompiled? ->
          Log.warning(
            :step,
            "The Rustler NIF #{name} is currently not supported! Burrito currently only supports `rustler_precompiled` NIFs!"
          )

          acc

        true ->
          acc
      end
    end)
  end

  defp find_dep(module, dep_name) do
    Enum.find(module.project[:deps], fn dep_tuple ->
      case dep_tuple do
        {^dep_name, _version} -> true
        {^dep_name, _version, _options} -> true
        _ -> false
      end
    end)
  end
end
