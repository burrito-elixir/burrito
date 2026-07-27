defmodule Burrito.Util.ZigResolver do
  @moduledoc """
  Resolves a path to a `zig` executable matching Burrito's pinned version
  (see `Burrito.get_versions/0`), in this order:

    1. `BURRITO_ZIG_PATH` environment variable, if set — an explicit override. Still
       validated (must exist and report the pinned version) so a typo or wrong-version
       override fails clearly here instead of confusingly deep in a build step.
    2. A previously downloaded, managed copy at the pinned version, if already cached.
    3. The system `zig` on `$PATH`, if its version matches the pinned version exactly —
       this preserves today's behavior unchanged for anyone who already has the right
       version installed.
    4. Otherwise, download the pinned version for the current host OS/CPU, verify its
       checksum, cache it, and use that.

  Only the exact pinned version is ever used to build — Burrito's own `build.zig`
  sources have historically only been compatible with one zig version at a time (see
  the 0.15 -> 0.16 migration), so accepting "any installed zig" isn't a safe
  relaxation of the old check. This resolver removes the need for the *system* to
  have zig installed at all, and stops an incompatible system zig from blocking a
  build, without weakening which zig version actually gets used.
  """

  alias Burrito.Builder.Log
  alias Burrito.Util
  alias Burrito.Util.Downloader
  alias Burrito.Util.FileCache

  # sha256 checksums for the pinned zig release, one per (os, cpu) Burrito supports
  # building on. Sourced from https://ziglang.org/download/index.json for the
  # version in Burrito.get_versions().zig -- update alongside that version.
  @zig_checksums %{
    {:linux, :x86_64} => "70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00",
    {:linux, :aarch64} => "ea4b09bfb22ec6f6c6ceac57ab63efb6b46e17ab08d21f69f3a48b38e1534f17",
    {:darwin, :x86_64} => "0387557ed1877bc6a2e1802c8391953baddba76081876301c522f52977b52ba7",
    {:darwin, :aarch64} => "b23d70deaa879b5c2d486ed3316f7eaa53e84acf6fc9cc747de152450d401489",
    {:windows, :x86_64} => "68659eb5f1e4eb1437a722f1dd889c5a322c9954607f5edcf337bc3684a75a7e"
  }

  @spec resolve() :: {:ok, String.t()} | {:error, String.t()}
  def resolve do
    expected = Burrito.get_versions().zig

    with :miss <- from_override(expected),
         :miss <- from_managed_cache(expected),
         :miss <- from_system_path(expected) do
      download_and_cache(expected)
    end
  end

  @spec zig_version_at(String.t()) :: {:ok, Version.t()} | :error
  def zig_version_at(path) do
    case System.cmd(path, ["version"]) do
      {out, 0} -> {:ok, out |> String.trim() |> Version.parse!()}
      _ -> :error
    end
  rescue
    _ -> :error
  end

  defp from_override(expected) do
    case System.get_env("BURRITO_ZIG_PATH") do
      nil ->
        :miss

      path ->
        cond do
          not File.regular?(path) ->
            {:error, "BURRITO_ZIG_PATH is set to `#{path}`, but no file exists there!"}

          true ->
            case zig_version_at(path) do
              {:ok, ^expected} ->
                Log.info(:step, "Using BURRITO_ZIG_PATH override: #{path}")
                {:ok, path}

              {:ok, other} ->
                {:error,
                 "BURRITO_ZIG_PATH points at Zig #{other}, but Burrito requires exactly " <>
                   "#{expected}!"}

              :error ->
                {:error,
                 "BURRITO_ZIG_PATH is set to `#{path}`, but it doesn't look like a working " <>
                   "`zig` binary!"}
            end
        end
    end
  end

  defp from_managed_cache(expected) do
    path = managed_zig_path(expected)

    if File.exists?(path) do
      Log.info(:step, "Using cached managed Zig #{expected}: #{path}")
      {:ok, path}
    else
      :miss
    end
  end

  defp from_system_path(expected) do
    case System.find_executable("zig") do
      nil ->
        :miss

      path ->
        case zig_version_at(path) do
          {:ok, ^expected} -> {:ok, path}
          _ -> :miss
        end
    end
  end

  defp download_and_cache(expected) do
    os = Util.get_current_os()
    cpu = Util.get_current_cpu()

    case Map.fetch(@zig_checksums, {os, cpu}) do
      :error ->
        {:error,
         "No managed Zig download is known for #{os}/#{cpu}. Install Zig #{expected} " <>
           "yourself and set BURRITO_ZIG_PATH to point at it."}

      {:ok, expected_sha256} ->
        Log.info(
          :step,
          "No compatible Zig found on PATH; fetching managed Zig #{expected} for #{os}/#{cpu}..."
        )

        fetch_and_install(os, cpu, expected, expected_sha256)
    end
  end

  defp fetch_and_install(os, cpu, version, expected_sha256) do
    archive_ext = if os == :windows, do: "zip", else: "tar.xz"
    file_name = "zig-#{cpu}-#{zig_os_name(os)}-#{version}.#{archive_ext}"
    url = "https://ziglang.org/download/#{version}/#{file_name}"
    cache_key = :crypto.hash(:sha, url) |> Base.encode16()

    archive_bytes =
      case FileCache.fetch(cache_key) do
        {:hit, data} ->
          Log.info(:step, "Found matching cached Zig download, using that")
          data

        _ ->
          do_download(url, cache_key)
      end

    if sha256(archive_bytes) != expected_sha256 do
      {:error,
       "Checksum mismatch for #{file_name}! Expected #{expected_sha256}, got " <>
         "#{sha256(archive_bytes)}. Refusing to use this download."}
    else
      install(archive_bytes, archive_ext, os, version)
    end
  end

  defp do_download(url, cache_key) do
    Log.info(:step, "Downloading: #{url}")
    resp = Downloader.get!(url)

    if resp.status != 200 do
      raise "Failed to download Zig from #{url}! (Got #{resp.status}) -- please file an issue! Thanks!"
    end

    FileCache.put_if_not_exist(cache_key, resp.body)
    resp.body
  end

  defp install(archive_bytes, archive_ext, os, version) do
    File.mkdir_p!(managed_root())

    # unique_integer/1 alone is only unique per-VM, not across concurrent OS processes
    extract_dir =
      Path.join(
        managed_root(),
        "extract-#{System.pid()}-#{:erlang.unique_integer([:positive])}"
      )

    File.mkdir_p!(extract_dir)

    with :ok <- extract(archive_bytes, archive_ext, extract_dir),
         {:ok, unpacked_dir} <- sole_entry(extract_dir) do
      result = place_install(unpacked_dir, version, os)
      File.rm_rf!(extract_dir)
      result
    else
      {:error, reason} ->
        File.rm_rf!(extract_dir)
        {:error, reason}
    end
  end

  # first writer wins -- adopt a concurrent build's install rather than clobber it
  defp place_install(unpacked_dir, version, os) do
    install_dir = managed_install_dir(version)
    zig_path = managed_zig_path(version)

    if File.exists?(zig_path) do
      Log.info(
        :step,
        "Managed Zig #{version} was already installed by a concurrent build, using that"
      )
    else
      File.mkdir_p!(Path.dirname(install_dir))

      case File.rename(unpacked_dir, install_dir) do
        :ok ->
          if os != :windows, do: File.chmod!(zig_path, 0o755)

        {:error, _reason} ->
          # lost the race between the check above and this rename
          unless File.exists?(zig_path) do
            raise "Failed to install Zig #{version} to #{install_dir}"
          end
      end
    end

    Log.success(:step, "Installed managed Zig #{version}: #{zig_path}")
    {:ok, zig_path}
  end

  defp extract(bytes, "tar.xz", dest_dir) do
    tmp_tar = Path.join(dest_dir, "archive.tar.xz")
    File.write!(tmp_tar, bytes)

    case System.cmd("tar", ["-xJf", tmp_tar, "-C", dest_dir]) do
      {_, 0} ->
        File.rm(tmp_tar)
        :ok

      {out, _} ->
        {:error, "Failed to extract Zig tarball: #{out}"}
    end
  end

  defp extract(bytes, "zip", dest_dir) do
    tmp_zip = Path.join(dest_dir, "archive.zip")
    File.write!(tmp_zip, bytes)

    case :zip.extract(String.to_charlist(tmp_zip), cwd: String.to_charlist(dest_dir)) do
      {:ok, _} ->
        File.rm(tmp_zip)
        :ok

      {:error, reason} ->
        {:error, "Failed to extract Zig archive: #{inspect(reason)}"}
    end
  end

  # find the archive's sole top-level dir, and confirm it didn't escape dest_dir
  defp sole_entry(dir) do
    case File.ls!(dir) |> Enum.reject(&(&1 in ["archive.tar.xz", "archive.zip"])) do
      [only] ->
        entry_path = Path.join(dir, only)
        expanded_dir = Path.expand(dir)

        if String.starts_with?(Path.expand(entry_path), expanded_dir <> "/") do
          {:ok, entry_path}
        else
          {:error, "Extracted Zig archive's top-level entry escaped the extraction directory"}
        end

      other ->
        {:error, "Expected exactly one entry in extracted Zig archive, got: #{inspect(other)}"}
    end
  end

  defp managed_install_dir(version) do
    os = Util.get_current_os()
    cpu = Util.get_current_cpu()
    Path.join([managed_root(), "#{version}-#{os}-#{cpu}"])
  end

  defp managed_zig_path(version) do
    exe = if Util.get_current_os() == :windows, do: "zig.exe", else: "zig"
    Path.join(managed_install_dir(version), exe)
  end

  defp managed_root do
    :filename.basedir(:user_cache, "burrito_file_cache") |> to_string() |> Path.join("zig")
  end

  defp zig_os_name(:darwin), do: "macos"
  defp zig_os_name(:windows), do: "windows"
  defp zig_os_name(:linux), do: "linux"

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)
end
