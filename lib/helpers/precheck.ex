defmodule Burrito.Helpers.Precheck do
  require Logger

  def run do
    {_, seven7_check} = System.cmd("which", ["7z"])
    {_, zig_check} = System.cmd("which", ["zig"])
    {_, gzip_check} = System.cmd("which", ["gzip"])
    {_, patch_check} = System.cmd("which", ["patch"])

    if seven7_check + zig_check + gzip_check + patch_check > 0 do
      Logger.error(
        "You MUST have `zig`, `gzip`, `patch` and `7z` installed to use Burrito, we couldn't find all of them in your PATH!"
      )

      exit(1)
    end
  end
end
