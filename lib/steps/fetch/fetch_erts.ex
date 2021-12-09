defmodule Burrito.Steps.Fetch.FetchERTS do
  @moduledoc """
  This step will copy/download and unpack a replacement ERTS for use later in the build flow.
  """

  alias Burrito.Util.FileCache

  alias Burrito.Builder.Context
  alias Burrito.Builder.Log
  alias Burrito.Builder.Step
  alias Burrito.Builder.Target

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    case context.erts_location do
      {:release, _} -> context # nothing to do! use the ERTS that's already in the mix release
      {:local, _} ->
        unpacked_url = get_erts(context.erts_location, context.target)
        %Context{context | erts_location: {:unpacked, unpacked_url}}
      {:url, _} ->
        unpacked_url = get_erts(context.erts_location, context.target)
        %Context{context | erts_location: {:unpacked, unpacked_url}}
      _ ->
        context
    end
  end

  defp get_erts({:local, local_tar}, target) do
    path = Path.absname(local_tar)
    data = File.read!(path)
    do_unpack(data, target)
  end

  defp get_erts({:url, tar_url}, target) do
    cache_key = :crypto.hash(:sha, tar_url) |> Base.encode16()

    case FileCache.fetch(cache_key) do
      {:hit, data} ->
        Log.info(:step, "Found matching cached ERTS, using that")
        do_unpack(data, target)
      _ ->
        do_download(tar_url, cache_key) |> do_unpack(target)
    end
  end

  defp do_unpack(data, %Target{} = target) do
    # save the payload somewhere
    random_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    tar_dest_path = System.tmp_dir!() |> Path.join(["erts_#{random_id}"])
    File.write!(tar_dest_path, data)

    random_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    extraction_path = System.tmp_dir!() |> Path.join(["unpacked_erts_#{random_id}"])
    File.mkdir_p!(extraction_path)

    # we use 7z to unpack windows setup files, otherwise we use tar
    command = case target.os do
      :windows -> ~c"7z x #{tar_dest_path} -o#{extraction_path}/otp-windows/"
      _ -> ~c"tar xzf #{tar_dest_path} -C #{extraction_path}"
    end

    :os.cmd(command)

    File.rm!(tar_dest_path)

    extraction_path
  end

  defp do_download(url, cache_key) do
    Log.info(:step, "Downloading file: #{url}")
    data = Req.get!(url).body
    FileCache.put_if_not_exist(cache_key, data)
    data
  end
end
