defmodule Burrito.Steps.Fetch.FetchMusl do
  alias Burrito.Builder.Context
  alias Burrito.Builder.Log
  alias Burrito.Builder.Step
  alias Burrito.Builder.Target

  alias Burrito.Util.FileCache

  # Linked against musl libc v1.2.5
  @linux_musl_url "https://beam-machine-universal.b-cdn.net/musl/libc-musl-{HASH}.so"
  @linux_musl_runtime_x86_64 "71c35316aff45bbfd243d8eb9bfc4a58b6eb97cee09514cd2030e145b68107fb"
  @linux_musl_runtime_aarch64 "6b558025200a5ed1308e2ce2675217afec71b6c5a9d561e52262ca948d59905e"

  @please_do_not_abuse_these_downloads_bandwidth_costs_money "?please-respect-my-bandwidth-costs=thank-you"

  @behaviour Step

  @impl Step
  def execute(
        %Context{target: %Target{os: :linux, cpu: arch, erts_source: {:precompiled, _}} = _target} =
          context
      ) do
    Log.info(:step, "Fetching musl libc runtime binary for Linux...")

    so_url = fetch_musl_runtime(arch) |> to_string()
    cache_key = :crypto.hash(:sha, so_url) |> Base.encode16()

    so_bytes =
      case FileCache.fetch(cache_key) do
        {:hit, data} ->
          Log.info(:step, "Found matching cached musl runtime, using that")
          data

        _ ->
          do_download(so_url, cache_key)
      end

    out_path = Path.join([context.self_dir, "src", "musl-runtime.so"])
    File.write!(out_path, so_bytes)

    Log.success(:step, "Wrote musl runtime file: #{out_path}")

    %Context{
      context
      | extra_build_env:
          context.extra_build_env ++
            [{"__BURRITO_MUSL_RUNTIME_PATH", "/tmp/libc-musl-#{get_runtime_hash(arch)}.so"}]
    }
  end

  def execute(context), do: context

  defp do_download(url, cache_key) do
    {:ok, _} = Application.ensure_all_started(:req)
    Log.info(:step, "Downloading file: #{url}")

    resp =
      case Burrito.Util.get_proxy() do
        proxy = %{scheme: scheme, host: host, port: port} when scheme in ["http", "https"] ->
          Log.info(:step, "Using PROXY: #{proxy}")
          proxy = {String.to_atom(scheme), host, port, []}
          Req.get!(url, raw: true, connect_options: [proxy: proxy])

        _ ->
          Req.get!(url, raw: true)
      end

    if resp.status != 200 do
      raise "Failed to fetch musl runtime: #{url}! (Got #{resp.status}) -- please file an issue! Thanks!"
    end

    FileCache.put_if_not_exist(cache_key, resp.body)
    resp.body
  end

  defp fetch_musl_runtime(arch) do
    (String.replace(@linux_musl_url, "{HASH}", get_runtime_hash(arch)) <>
       @please_do_not_abuse_these_downloads_bandwidth_costs_money)
    |> URI.parse()
  end

  defp get_runtime_hash(:x86_64), do: @linux_musl_runtime_x86_64
  defp get_runtime_hash(:aarch64), do: @linux_musl_runtime_aarch64
end
