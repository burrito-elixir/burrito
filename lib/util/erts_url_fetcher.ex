defmodule Burrito.Util.ERTSUrlFetcher do
  alias Burrito.Builder.Log

  @versions_url_darwin_linux "https://api.github.com/repos/burrito-elixir/erlang-builder/releases?per_page=100"
  @versions_url_windows "https://api.github.com/repos/erlang/otp/releases?per_page=100"

  @spec fetch_all_versions() :: %{windows: list(), posix: list()}
  def fetch_all_versions() do
    {:ok, _} = Application.ensure_all_started(:req)

    with {:ok, windows_releases} <- get_gh_pages(@versions_url_windows),
         {:ok, posix_releases} <- get_gh_pages(@versions_url_darwin_linux) do
      %{windows: windows_releases, posix: posix_releases}
    else
      {:error, message} ->
        Log.error(
          :step,
          "Error occurred when trying to fetch releases from Github\n\t Reason: #{message}"
        )

        %{windows: [], posix: []}
    end
  end

  @spec fetch_version(atom(), atom(), atom(), String.t()) :: URI.t() | {:error, atom()}
  def fetch_version(os, libc, cpu, otp_version)
      when is_binary(otp_version) and is_atom(os) and is_atom(cpu) and is_atom(libc) do
    all_versions = fetch_all_versions()

    res =
      if os == :windows do
        all_versions.windows
      else
        all_versions.posix
      end

    platform_string =
      if os == :windows do
        "win64"
      else
        if os == :darwin do
          case cpu do
            :x86_64 -> "darwin-x86_64"
            :aarch64 -> "darwin-arm64"
            :arm64 -> "darwin-arm64"
          end
        else
          case libc do
            :musl -> "musl_libc"
            :glibc -> "linux"
          end
        end
      end

    versions =
      Enum.map(res, fn release ->
        version = String.replace_leading(release["tag_name"], "OTP-", "")

        asset =
          release["assets"]
          |> Enum.find(fn asset -> String.contains?(asset["name"], platform_string) end)

        {version, asset["browser_download_url"]}
      end)

    result =
      Enum.find(versions, fn {v, download_url} ->
        v == otp_version && download_url != nil
      end)

    if result do
      {_, url} = result
      url |> URI.parse()
    else
      {:error, :no_result}
    end
  end

  defp get_gh_pages(url, page \\ 1, acc \\ []) do
    # page through all the asset results until we have no more
    # then return the full list of them
    case Req.get!(url <> "&page=#{page}") do
      %Req.Response{status: 200, body: []} ->
        {:ok, acc}

      %Req.Response{status: 200, body: data} ->
        get_gh_pages(url, page + 1, data ++ acc)

      %Req.Response{} = bad_response ->
        {:error, bad_response.body["message"]}
    end
  end
end
