defmodule Burrito.Util.DefaultERTSResolver do
  alias Burrito.Builder.Target
  alias Burrito.Builder.Log

  alias Burrito.Util
  alias Burrito.Util.FileCache
  alias Burrito.Util.ERTSResolver
  alias Burrito.Util.ERTSUrlFetcher

  @behaviour ERTSResolver

  @impl ERTSResolver
  @spec do_resolve(Burrito.Builder.Target.t()) :: Burrito.Builder.Target.t()
  def do_resolve(%Target{erts_source: {:runtime, _}} = target) do
    %Target{target | erts_source: {:runtime, version: Util.get_otp_version()}}
  end

  def do_resolve(%Target{erts_source: {:precompiled, version: otp_version}} = target)
      when is_binary(otp_version) do
    case ERTSUrlFetcher.fetch_version(
           target.os,
           target.qualifiers[:libc],
           target.cpu,
           otp_version
         ) do
      %URI{} = location ->
        %Target{target | erts_source: {:url, url: location}} |> do_resolve()

      {:error, err} ->
        Log.error(
          :step,
          "Failed to fetch a precompiled Erlang (version #{otp_version})!\n\t Reason: #{translate_resolve_error(err)}"
        )

        %Target{target | erts_source: {:unresolved, err}}
    end
  end

  def do_resolve(%Target{erts_source: {:local, path: location}} = target) do
    archive_data = File.read!(location)
    unpacked_location = do_unpack(archive_data, target)

    %Target{target | erts_source: {:local_unpacked, path: unpacked_location}}
  end

  def do_resolve(%Target{erts_source: {:url, url: location}} = target) do
    url_string = URI.to_string(location)
    archive_data = get_erts(url_string)
    unpacked_location = do_unpack(archive_data, target)

    %Target{target | erts_source: {:local_unpacked, path: unpacked_location}}
  end

  defp get_erts(tar_url) do
    cache_key = :crypto.hash(:sha, tar_url) |> Base.encode16()

    case FileCache.fetch(cache_key) do
      {:hit, data} ->
        Log.info(:step, "Found matching cached ERTS, using that")
        data

      _ ->
        do_download(tar_url, cache_key)
    end
  end

  # Req can decompress the body into a list of {filename, filedata}
  defp do_unpack(data, _target) when is_list(data) do
    random_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    extraction_path = System.tmp_dir!() |> Path.join(["unpacked_erts_#{random_id}"])
    File.mkdir_p!(extraction_path)

    Enum.each(data, fn {filename, filedata} ->
      path = Path.join(extraction_path, filename)

      path
      |> Path.dirname()
      |> File.mkdir_p!()

      File.write!(path, filedata)
    end)

    extraction_path
  end

  defp do_unpack(data, %Target{} = target) when is_binary(data) do
    # save the payload somewhere
    random_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    tar_dest_path = System.tmp_dir!() |> Path.join(["erts_#{random_id}"])
    File.write!(tar_dest_path, data)

    random_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    extraction_path = System.tmp_dir!() |> Path.join(["unpacked_erts_#{random_id}"])
    File.mkdir_p!(extraction_path)

    # we use 7z to unpack windows setup files, otherwise we use tar
    command =
      case target.os do
        :windows -> ~c"7z x #{tar_dest_path} -o#{extraction_path}/otp-windows/"
        _ -> ~c"tar xzf #{tar_dest_path} -C #{extraction_path}"
      end

    :os.cmd(command)

    File.rm!(tar_dest_path)

    Log.info(:step, "Unpacked ERTS to: #{extraction_path}")

    extraction_path
  end

  defp do_download(url, cache_key) do
    {:ok, _} = Application.ensure_all_started(:req)
    Log.info(:step, "Downloading file: #{url}")
    data = Req.get!(url).body
    FileCache.put_if_not_exist(cache_key, data)
    data
  end

  defp translate_resolve_error(:no_result),
    do:
      "No pre-compiled version matching this combination of platform, arch, and libc was found on our CI system."
end
