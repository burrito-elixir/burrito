defmodule Burrito.Helpers.Precheck do
  require Logger

  def run do
    if Enum.any?(~w(7z zig gzip), &(System.find_executable(&1) == nil)) do
      Logger.error(
        "You MUST have `zig`, `gzip` and `7z` installed to use Burrito, we couldn't find all of them in your PATH!"
      )

      exit(1)
    end
  end
end
