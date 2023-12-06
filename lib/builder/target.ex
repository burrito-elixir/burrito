defmodule Burrito.Builder.Target do
  use TypedStruct

  alias __MODULE__
  alias Burrito.Util

  @type erts_source ::
          {:unresolved | :runtime | :precompiled | :local | :local_unpacked | :url,
           keyword() | atom()}

  typedstruct enforce: true do
    field(:alias, atom())
    field(:cpu, atom())
    field(:os, atom())
    field(:cross_build, boolean)
    field(:qualifiers, keyword())
    field(:erts_source, erts_source())
    field(:debug?, boolean())
  end

  def init_target(target_alias, definition) do
    # pop off required options, then erts definitions
    {fields, qualifiers} = Keyword.split(definition, [:os, :cpu, :debug?])
    {custom_erts, qualifiers} = Keyword.pop(qualifiers, :custom_erts)

    if !fields[:os] || !fields[:cpu] do
      raise "You must define your target with AT LEAST `:os`, `:cpu` defined!"
    end

    erts_source = translate_erts_source(custom_erts)

    fields =
      fields
      |> Keyword.put(:alias, target_alias)
      |> Keyword.put(:erts_source, erts_source)
      |> Keyword.put(:debug?, fields[:debug?] || false)
      |> Keyword.put(:qualifiers, qualifiers)
      |> Keyword.put(:cross_build, is_cross_build?(fields))

    struct!(__MODULE__, fields)
  end

  defp translate_erts_source(custom_location) do
    if custom_location do
      cond do
        is_uri?(custom_location) ->
          {:url, url: custom_location}

        String.ends_with?(custom_location, ".tar.gz") or
            String.ends_with?(custom_location, ".exe") ->
          {:local, path: custom_location}

        File.dir?(custom_location) ->
          {:local_unpacked, path: custom_location}

        true ->
          raise "`:custom_erts` was not a URL, local path to tarball/compressed-exe, or local path to a directory"
      end
    else
      {:precompiled, version: Util.get_otp_version()}
    end
  end

  defp is_uri?(string) do
    case URI.parse(string) do
      %URI{scheme: nil} -> false
      %URI{host: nil, path: nil} -> false
      _ -> true
    end
  end

  defp is_cross_build?(fields) do
    fields[:os] != Util.get_current_os() || fields[:cpu] != Util.get_current_cpu() or
      fields[:os] == :linux
  end

  @spec make_triplet(Burrito.Builder.Target.t()) :: String.t()
  def make_triplet(%Target{} = target) do
    os =
      case target.os do
        :darwin -> "macos"
        :windows -> "windows"
        :linux -> "linux"
      end

    triplet = "#{target.cpu}-#{os}"

    if target.qualifiers[:os] == :linux do
      "#{triplet}-musl"
    else
      triplet
    end
  end
end
