defmodule Burrito.Steps.Fetch.InitBuild do
  @moduledoc """
  This build step does some sanity checking between the target we're building for, and the host machine
  If it determines we are cross-building, it will check to ensure an ERTS build is available for the target.
  """
  alias Burrito.Builder.Context
  alias Burrito.Builder.Log
  alias Burrito.Builder.Target
  alias Burrito.Builder.Step
  alias Burrito.Util

  # URLs used to fetch pre-compiled versions of the ERTS
  @versions_url_darwin_linux "https://api.github.com/repos/burrito-elixir/erlang-builder/releases?per_page=100"
  @versions_url_windows "https://api.github.com/repos/erlang/otp/releases?per_page=100"

  # This is a list of precompiled ERTS releases we provide in the Burrito project
  # any other build tuples will need to be provided using the `:local_erts` release option.
  @pre_compiled_supported_tuples [
    #{os, cpu, libc (linux only)}
    {:windows, :x86_64, nil},
    {:darwin, :x86_64, nil},
    {:linux, :x86_64, :glibc},
    {:linux, :x86_64, :musl}
  ]

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    {:ok, _} = Application.ensure_all_started(:req)

    random_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    work_dir = System.tmp_dir!() |> Path.join(["burrito_build_#{random_id}"])
    File.cp_r(context.mix_release.path, work_dir, fn _, _ -> true end)

    cross_build =
      context.target.os != Util.get_current_os() || context.target.cpu != Util.get_current_cpu() ||
        context.target.qualifiers[:libc] != Util.get_libc_type()

    if cross_build do
      case check_erts_builds(context) do
        :error ->
          Log.error(
            :step,
            "We do not have a pre-compiled ERTS release for the target requested, and you have not specified a matching custom ERTS release in your mix.exs file!"
          )

          %Context{
            context
            | cross_build: true,
              halt: true,
              work_dir: work_dir
          }

        location_info ->
          %Context{context | cross_build: true, erts_location: location_info, work_dir: work_dir}
      end
    else
      # we're not going to do any replacements
      %Context{context | cross_build: false, erts_location: {:release, nil}, work_dir: work_dir}
    end
  end

  defp check_erts_builds(%Context{} = context) do
    tuple = {context.target.os, context.target.cpu, context.target.qualifiers[:libc]}
    custom_erts_def = context.target.qualifiers[:local_erts]

    if custom_erts_def do
      Log.info(:step, "This build will use local ERTS tar: #{custom_erts_def}")
      {:local, custom_erts_def}
    end

    if tuple in @pre_compiled_supported_tuples do
      get_otp_url(context.target)
    else
      :error
    end
  end

  defp get_otp_url(%Target{} = target) do
    target_match = {target.os, Keyword.take(target.qualifiers, [:libc])}

    {res, platform_string} =
      case target_match do
        {:darwin, _} ->
          {Req.get!(@versions_url_darwin_linux).body, "darwin"}

        {:linux, [libc: :glibc]} ->
          {Req.get!(@versions_url_darwin_linux).body, "linux"}

        {:linux, [libc: :musl]} ->
          {Req.get!(@versions_url_darwin_linux).body, "musl_libc"}

        {:windows, _} ->
          {Req.get!(@versions_url_windows).body, "win64"}

        _ ->
          {nil, nil}
      end

    if res == nil do
      :error
    else
      versions =
        Enum.map(res, fn release ->
          version = String.replace_leading(release["tag_name"], "OTP-", "")

          asset =
            release["assets"]
            |> Enum.find(fn asset -> String.contains?(asset["name"], platform_string) end)

          {version, asset["browser_download_url"]}
        end)

      {_, url} =
        Enum.find(versions, fn {v, download_url} ->
          v == target.otp_version && download_url != nil
        end)

      {:url, url}
    end
  end
end
