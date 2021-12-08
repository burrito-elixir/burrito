defmodule Burrito.Steps.Fetch.InitBuild do
  @moduledoc """
  This build step does some sanity checking between the target we're building for, and the host machine
  If it determines we are cross-building, it will check to ensure an ERTS build is available for the target.
  """
  alias Burrito.Builder.Context
  alias Burrito.Builder.Target
  alias Burrito.Builder.Step
  alias Burrito.Util

  # URLs used to fetch pre-compiled versions of the ERTS
  @versions_url_darwin_linux "https://api.github.com/repos/burrito-elixir/erlang-builder/releases?per_page=100"
  @versions_url_windows "https://api.github.com/repos/erlang/otp/releases?per_page=100"

  # This is a list of pre-compiled ERTS releases we provide in the Burrito project
  # any other build tuples will need to be provided using the `:local_erts` release option.
  @pre_compiled_supported_tuples [
    {:windows, :x86_64, :none},
    {:darwin, :x86_64, :none},
    {:linux, :x86_64, :gnu},
    {:linux, :x86_64, :musl}
  ]

  @behaviour Step

  @impl Step
  def execute(%Context{} = context) do
    {:ok, _} = Application.ensure_all_started(:req)

    cross_build =
      context.target.os != Util.get_current_os() || context.target.cpu != Util.get_current_cpu() ||
        context.target.libc != Util.get_libc_type()

    if cross_build do
      case check_erts_builds(context) do
        {:ok, location_info} ->
          %Context{context | cross_build: true, erts_location: location_info}

        _ ->
          %Context{
            context
            | cross_build: true,
              halt: true,
              errors: [
                "We do not have a pre-compiled ERTS release for the target requested, and you have not specified a matching custom ERTS release in your mix.exs file!"
              ]
          }
      end
    else
      # we're not going to do any replacements
      %Context{context | cross_build: false, erts_location: {:release, nil}}
    end
  end

  defp check_erts_builds(%Context{} = context) do
    tuple = {context.target.os, context.target.cpu, context.target.libc}
    custom_erts_defs = context.mix_release.options[:burrito][:local_erts] || %{}

    if tuple not in @pre_compiled_supported_tuples && !Map.has_key?(custom_erts_defs, tuple) do
      :error
    else
      if Map.has_key?(custom_erts_defs, tuple) do
        {:ok, {:local, custom_erts_defs[tuple]}}
      else
        {:ok, get_otp_url(context.target)}
      end
    end
  end

  defp get_otp_url(%Target{} = target) do
    {res, platform_string} =
      case target do
        %Target{os: :darwin} ->
          {Req.get!(@versions_url_darwin_linux).body, "darwin"}

        %Target{os: :linux, libc: :gnu} ->
          {Req.get!(@versions_url_darwin_linux).body, "linux"}

        %Target{os: :linux, libc: :musl} ->
          {Req.get!(@versions_url_darwin_linux).body, "musl_libc"}

        %Target{os: :windows} ->
          {Req.get!(@versions_url_windows).body, "win64"}

        _ ->
          nil
      end

    versions =
      Enum.map(res, fn release ->
        version = String.replace_leading(release["tag_name"], "OTP-", "")

        asset =
          release["assets"]
          |> Enum.find(fn asset -> String.contains?(asset["name"], platform_string) end)

        {version, asset["browser_download_url"]}
      end)

    {_, url} = Enum.find(versions, fn {v, download_url} -> v == target.otp_version && download_url != nil end)

    {:url, url}
  end
end
