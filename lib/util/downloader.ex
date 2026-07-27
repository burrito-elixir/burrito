defmodule Burrito.Util.Downloader do
  @moduledoc """
  Shared HTTP GET used by Burrito's own download steps (musl runtime, managed Zig,
  ...) -- proxy-aware, raw bytes. Raises on transport failure, same as the plain
  `Req.get!/2` it wraps; callers are responsible for checking `resp.status`.
  """

  alias Burrito.Builder.Log
  alias Burrito.Util

  @spec get!(String.t()) :: Req.Response.t()
  def get!(url) do
    {:ok, _} = Application.ensure_all_started(:req)

    case Util.get_proxy() do
      proxy = %{scheme: scheme, host: host, port: port} when scheme in ["http", "https"] ->
        Log.info(:step, "Using PROXY: #{proxy}")
        proxy = {String.to_atom(scheme), host, port, []}
        Req.get!(url, raw: true, connect_options: [proxy: proxy])

      _ ->
        Req.get!(url, raw: true)
    end
  end
end
