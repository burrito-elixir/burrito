defmodule Burrito do
  alias Burrito.Builder
  alias Burrito.Builder.Log

  @spec wrap(Mix.Release.t()) :: Mix.Release.t()
  def wrap(%Mix.Release{} = release) do
    pre_check()
    Builder.build(release)
  end

  def register_erts_resolver(module) when is_atom(module) do
    Application.put_env(:burrito, :erts_resolver, module)
  end

  defp pre_check do
    if Enum.any?(~w(7z zig gzip), &(System.find_executable(&1) == nil)) do
      Log.error(:build, "You MUST have `zig`, `gzip` and `7z` installed to use Burrito, we couldn't find all of them in your PATH!")
      exit(1)
    end
  end
end
