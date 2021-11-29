defmodule Burrito.Helpers.Precheck do
  require Logger

  def run do
    if Enum.any?(~w(7z zip gzip patch), &(System.find_executable(&1) == nil)) do
      Logger.error(
        "You MUST have `zig`, `gzip`, `patch` and `7z` installed to use Burrito, we couldn't find all of them in your PATH!"
      )

      exit(1)
    end
  end
end
