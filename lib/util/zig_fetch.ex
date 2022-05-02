defmodule Burrito.Util.ZigFetch do
  alias Burrito.Util
  require Logger

  # Index of all Zig releases
  @zig_srouce "https://ziglang.org/download/index.json"

  # The version of Zig burrito is currently using
  @zig_version "0.10.0"

  @spec auto_fetch :: :error | :ok
  def auto_fetch do
    cpu = Util.get_current_cpu()
    os = Util.get_current_os()
    fetch_zig(os, cpu)
  end

  @spec fetch_zig(any, any) :: :error | :ok
  def fetch_zig(os, cpu) do
    extracted_stamp = Path.join([compute_install_location(), "/EXTRACTED.stamp"])

    if File.exists?(extracted_stamp) do
      Logger.info(
        "Zig #{@zig_version} is already installed at #{compute_install_location()} for #{os} #{cpu}"
      )

      :ok
    else
      Logger.info("Fetching Zig for your host platform...")

      release_index = fetch_release_index()

      case fetch_archive(os, cpu, release_index) do
        {:ok, data} ->
          do_unpack(data, compute_install_location())

        _ ->
          :error
      end
    end
  end

  @spec compute_install_location :: binary
  def compute_install_location() do
    self_path =
      __ENV__.file
      |> Path.dirname()
      |> Path.split()
      |> List.delete_at(-1)
      |> List.delete_at(-1)
      |> List.insert_at(-1, "zig_bin_#{@zig_version}")
      |> Path.join()

    File.mkdir_p!(self_path)

    self_path
  end

  defp fetch_release_index() do
    case Req.get!(@zig_srouce) do
      %Req.Response{status: 200, body: json_body} ->
        json_body

      _ ->
        Logger.error(
          "Error fetching Zig release index. Ensure you are connected to the internet."
        )

        :error
    end
  end

  defp fetch_archive(_os, _cpu, :error) do
    :error
  end

  defp fetch_archive(os, cpu, index) do
    releases = index[@zig_version] || []
    release_name = "#{cpu}-#{translate_os(os)}"

    {_, found_release} =
      Enum.find(releases, %{}, fn {name, _metadata} -> name == release_name end)

    if Map.has_key?(found_release, "tarball") do
      %Req.Response{status: 200, body: data} = Req.get!(found_release["tarball"])
      {:ok, data}
    else
      :error
    end
  end

  defp do_unpack(tarball_data, install_location) do
    out_archive = Path.join([install_location, "/zig.tar.xz"])
    File.write!(out_archive, tarball_data)

    {_, 0} =
      System.cmd("tar", ["-xf", "zig.tar.xz", "--strip-components", "1"], cd: install_location)

    stamp = Path.join([install_location, "/EXTRACTED.stamp"])
    File.touch!(stamp)
  end

  defp translate_os(:darwin), do: :macos
  defp translate_os(name), do: name
end
