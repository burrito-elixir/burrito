defmodule Burrito.Helpers.Clean do
  require Logger

  def run(self_path) do
    Logger.info("Cleaning up...")

    cache = Path.join(self_path, "zig-cache")
    out = Path.join(self_path, "zig-out")
    payload = Path.join(self_path, "payload.foilz.gz")
    metadata = Path.join(self_path, "_metadata.json")

    File.rmdir(cache)
    File.rmdir(out)
    File.rm(payload)
    File.rm(metadata)

    :ok
  end
end
