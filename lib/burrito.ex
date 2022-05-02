defmodule Burrito do
  alias Burrito.Builder
  alias Burrito.Builder.Log
  alias Burrito.Util.ZigFetch

  @spec wrap(Mix.Release.t()) :: Mix.Release.t()
  def wrap(%Mix.Release{} = release) do
    pre_check()

    {:ok, _} = Application.ensure_all_started(:req)

    ZigFetch.auto_fetch()
    Builder.build(release)
  end

  def register_erts_resolver(module) when is_atom(module) do
    Application.put_env(:burrito, :erts_resolver, module)
  end

  defp pre_check() do
    if Enum.any?(~w(xz), &(System.find_executable(&1) == nil)) do
      Log.error(
        :build,
        "You MUST have `xz` installed to use Burrito! We couldn't find it in your PATH!"
      )

      exit(1)
    end

    if Enum.any?(~w(7z), &(System.find_executable(&1) == nil)) do
      Log.warning(
        :build,
        "We couldn't find 7z in your PATH, 7z is required to build Windows releases. They will fail if you don't fix this!"
      )
    end
  end
end
