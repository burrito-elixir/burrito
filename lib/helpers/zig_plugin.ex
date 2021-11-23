defmodule Burrito.Helpers.ZigPlugins do
  require Logger

  def run(nil), do: nil

  def run(plugin_path) do
    Path.join(File.cwd!(), [plugin_path])
  end
end
