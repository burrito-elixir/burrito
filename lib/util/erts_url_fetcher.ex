defmodule Burrito.Util.ERTSUrlFetcher do
  alias Burrito.Builder.Log

  @versions_url_darwin_linux "https://api.github.com/repos/burrito-elixir/erlang-builder/releases"
  @versions_url_windows "https://api.github.com/repos/erlang/otp/releases"

  @spec fetch_version(atom(), atom(), atom(), String.t()) :: URI.t() | {:error, atom()}
  def fetch_version(os, libc, cpu, otp_version)
      when is_binary(otp_version) and is_atom(os) and is_atom(cpu) and is_atom(libc) do
    {:ok, _} = Application.ensure_all_started(:req)

    releases =
      if os == :windows do
        get_gh_pages(@versions_url_windows)
      else
        get_gh_pages(@versions_url_darwin_linux)
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
      Stream.map(releases, fn
        {:ok, release} ->
          version = String.replace_leading(release["tag_name"], "OTP-", "")

          asset =
            release["assets"]
            |> Enum.find(fn asset -> String.contains?(asset["name"], platform_string) end)

          {:ok, {version, asset["browser_download_url"]}}

        {:error, error} ->
          {:error, error}
      end)

    Stream.filter(versions, fn
      {:ok, {v, download_url}} -> v == otp_version && download_url != nil
      {:error, error} -> {:error, error}
    end)
    |> Enum.take(1)
    |> case do
      [{:ok, {_, url}}] ->
        url |> URI.parse()

      [{:error, message}] ->
        Log.error(
          :step,
          "Error occurred when trying to fetch releases from Github\n\t Reason: #{message}"
        )

        {:error, :no_result}

      [] ->
        {:error, :no_result}
    end
  end

  defp get_gh_pages(url, per_page \\ 100, page \\ 1) do
    # Return a stream of pages (is nicer to github and less likely to
    # rate-limit)
    Stream.unfold({:ok, page}, fn page ->
      with {:ok, page} <- page,
           page_url <- url <> "?per_page=#{per_page}&page=#{page}",
           %Req.Response{status: 200, body: data} <- Req.get!(page_url) do
        case data do
          [] -> nil
          data -> {{:ok, data}, {:ok, page + 1}}
        end
      else
        %Req.Response{body: body} -> {{:error, body["message"]}, :error}
        :error -> nil
      end
    end)
    |> Stream.flat_map(fn
      {:ok, x} -> Enum.map(x, &{:ok, &1})
      {:error, x} -> [{:error, x}]
    end)
  end
end
