defmodule Burrito.Steps.Build.PackAndBuild do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Log
  alias Burrito.Builder.Step
  alias Burrito.Builder.Target

  alias Burrito.Util.ZigFetch

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    options = context.mix_release.options[:burrito] || []
    release_name = Atom.to_string(context.mix_release.name)
    build_triplet = Target.make_triplet(context.target)

    plugin_path = maybe_get_plugin_path(options[:plugin])

    zig_build_args =
      if context.target.debug? do
        ["-Dtarget=#{build_triplet}"]
      else
        ["-Dtarget=#{build_triplet}", "-Drelease-small=true"]
      end

    create_metadata_file(context.self_dir, zig_build_args, context.mix_release)

    # TODO: Why do we need to do this???
    # This is to bypass a VERY strange bug inside Linux containers...
    # If we don't do this, the archiver will fail to see all the files inside the lib directory
    # This is still under investigation, but touching a file inside the directory seems to force the
    # File system to suddenly "wake up" to all the files inside it.
    Path.join(context.work_dir, ["/lib", "/.burrito"]) |> File.touch!()

    build_result =
      System.cmd(get_zig_path(), ["build"] ++ zig_build_args,
        cd: context.self_dir,
        env: [
          {"__BURRITO_IS_PROD", is_prod?()},
          {"__BURRITO_RELEASE_PATH", context.work_dir},
          {"__BURRITO_RELEASE_NAME", release_name},
          {"__BURRITO_PLUGIN_PATH", plugin_path}
        ],
        into: IO.stream()
      )

    if !options[:no_clean] do
      clean_build(context.self_dir)
    end

    case build_result do
      {_, 0} ->
        context

      _ ->
        Log.error(
          :step,
          "Burrito failed to wrap up your app! Check the logs for more information."
        )

        raise "Wrapper build failed"
    end
  end

  defp maybe_get_plugin_path(nil), do: nil

  defp maybe_get_plugin_path(plugin_path) do
    Path.join(File.cwd!(), [plugin_path])
  end

  defp create_metadata_file(self_path, args, release) do
    Log.info(:step, "Generating wrapper metadata file...")

    {zig_version_string, 0} = System.cmd(get_zig_path(), ["version"], cd: self_path)

    metadata_map = %{
      app_name: Atom.to_string(release.name),
      zig_version: zig_version_string |> String.trim(),
      zig_build_arguments: args,
      app_version: release.version,
      options: inspect(release.options),
      erts_version: release.erts_version |> to_string()
    }

    encoded = Jason.encode!(metadata_map)

    Path.join(self_path, ["src/", "_metadata.json"]) |> File.write!(encoded)
  end

  defp is_prod?() do
    if Mix.env() == :prod do
      "1"
    else
      "0"
    end
  end

  defp clean_build(self_path) do
    Log.info(:step, "Cleaning up...")

    cache = Path.join(self_path, "zig-cache")
    out = Path.join(self_path, "zig-out")
    payload = Path.join(self_path, "payload.foilz")
    compressed_payload = Path.join(self_path, ["src/", "payload.foilz.xz"])
    metadata = Path.join(self_path, ["src/", "_metadata.json"])

    File.rmdir(cache)
    File.rmdir(out)
    File.rm(payload)
    File.rm(compressed_payload)
    File.rm(metadata)

    :ok
  end

  defp get_zig_path() do
    [ZigFetch.compute_install_location(), "/zig"] |> Path.join()
  end
end
