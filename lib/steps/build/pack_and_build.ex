defmodule Burrito.Steps.Build.PackAndBuild do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Log
  alias Burrito.Builder.Step
  alias Burrito.Builder.Target

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    options = context.mix_release.options[:burrito] || []
    release_name = Atom.to_string(context.mix_release.name)
    build_triplet = Target.make_triplet(context.target)

    plugin_path = maybe_get_plugin_path(options[:plugin])

    build_args = ["--target=#{build_triplet}"]

    create_metadata_file(context.self_dir, context.work_dir, build_args, context.mix_release)

    # TODO: Why do we need to do this???
    # This is to bypass a VERY strange bug inside Linux containers...
    # If we don't do this, the archiver will fail to see all the files inside the lib directory
    # This is still under investigation, but touching a file inside the directory seems to force the
    # File system to suddenly "wake up" to all the files inside it.
    Path.join(context.work_dir, ["/lib", "/.burrito"]) |> File.touch!()

    build_env = [
      {"__BURRITO_IS_PROD", is_prod(context.target)},
      {"__BURRITO_RELEASE_PATH", context.work_dir},
      {"__BURRITO_RELEASE_NAME", release_name},
      {"__BURRITO_PLUGIN_PATH", plugin_path}
    ]

    Log.info(:step, "Zig build env: #{inspect(build_env)}")

    System.cmd("cargo", ["clean"], cd: Path.join(context.self_dir, "/wrapper"))

    build_result =
      System.cmd("cargo", ["build", "--message-format", "short"] ++ build_args,
        cd: Path.join(context.self_dir, "/wrapper"),
        env: build_env,
        into: IO.stream(),
        env: build_env
      )

    if !options[:no_clean] do
      clean_build(context.self_dir)
    end

    case build_result do
      {_, 0} ->
        context

      {out, code} ->
        Log.error(
          :step,
          "Burrito failed to wrap up your app! Check the logs for more information. #{inspect(out)}"
        )

        raise "Wrapper build failed, `cargo` exit code: #{code}"
    end
  end

  defp maybe_get_plugin_path(nil), do: nil

  defp maybe_get_plugin_path(plugin_path) do
    Path.join(File.cwd!(), [plugin_path])
  end

  defp create_metadata_file(self_path, work_dir, args, release) do
    Log.info(:step, "Generating wrapper metadata file...")

    {version_string, 0} =
      System.cmd("rustc", ["--version"], cd: self_path, stderr_to_stdout: true)

    metadata_map = %{
      app_name: Atom.to_string(release.name),
      rust_version: version_string |> String.trim(),
      cargo_build_arguments: args,
      app_version: release.version,
      options: inspect(release.options),
      erts_version: release.erts_version |> to_string()
    }

    encoded = Jason.encode!(metadata_map)

    Path.join(work_dir, ["_metadata.json"]) |> File.write!(encoded)
  end

  defp is_prod(%Target{debug?: debug?}) do
    cond do
      debug? -> "0"
      Mix.env() == :prod -> "1"
      true -> "0"
    end
  end

  defp clean_build(self_path) do
    Log.info(:step, "Cleaning up...")

    out = Path.join(self_path, "wrapper/target")
    payload = Path.join(self_path, "wrapper/payload.foilz")
    compressed_payload = Path.join(self_path, ["wrapper/", "payload.foilz.xz"])

    File.rmdir(out)
    File.rm(payload)
    File.rm(compressed_payload)

    :ok
  end
end
