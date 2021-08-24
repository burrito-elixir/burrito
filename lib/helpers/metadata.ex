defmodule Burrito.Helpers.Metadata do
  require Logger

  def run(self_path, args, release) do
    Logger.info("Generating wrapper metadata file...")

    {zig_version_string, 0} = System.cmd("zig", ["version"], cd: self_path)

    metadata_map = %{
      app_name: Atom.to_string(release.name),
      zig_version: zig_version_string |> String.trim(),
      zig_build_arguments: args,
      app_version: release.version,
      options: inspect(release.options),
      erts_version: release.erts_version |> to_string()
    }

    encoded = Jason.encode!(metadata_map)

    Path.join(self_path, "_metadata.json") |> File.write!(encoded)
  end
end
