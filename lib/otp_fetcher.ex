defmodule Burrito.OTPFetcher do
  use Tesla
  require Logger

  plug(Tesla.Middleware.FollowRedirects)

  @versions_url_darwin_linux "https://api.github.com/repos/burrito-elixir/erlang-builder/releases?per_page=100"
  @versions_url_windows "https://api.github.com/repos/erlang/otp/releases"

  @erl_launch_script """
  #!/bin/sh
  SELF=$(readlink "$0" || true)
  if [ -z "$SELF" ]; then SELF="$0"; fi
  BINDIR="$(cd "$(dirname "$SELF")" && pwd -P)"
  ROOTDIR="${ERL_ROOTDIR:-"$(dirname "$(dirname "$BINDIR")")"}"
  EMU=beam
  PROGNAME=$(echo "$0" | sed 's/.*\\///')
  export EMU
  export ROOTDIR
  export BINDIR
  export PROGNAME
  exec "$BINDIR/erlexec" ${1+"$@"}
  """

  @start_script """
  ROOTDIR="$ERL_ROOTDIR"

  if [ -z "$RELDIR" ]
  then
     RELDIR=$ROOTDIR/releases
  fi

  START_ERL_DATA=${1:-$RELDIR/start_erl.data}

  $ROOTDIR/bin/run_erl -daemon /tmp/ $ROOTDIR/log "exec $ROOTDIR/bin/start_erl $ROOTDIR $RELDIR $START_ERL_DATA"
  """

  plug(Tesla.Middleware.Headers, [{"user-agent", "Burrito.OTPFetcher"}])

  def download_and_replace_erts_release(erts_version, otp_version, release_path, platform) do
    versions = get_otp_versions(platform)

    selected_version =
      Enum.find(versions, fn {v, download_url} -> v == otp_version && download_url != nil end)

    # die if we cannot download that version
    if selected_version == nil do
      Logger.error(
        "Sorry! We cannot fetch the requested OTP version (OTP-#{otp_version}) for platform #{inspect(platform)} as it's not available in [burrito-elixir/erlang-builder] or [otp/releases]"
      )

      exit(1)
    end

    {_, download_url} = selected_version

    Logger.info("Downloading replacement ERTS: #{download_url}")

    data = get!(download_url)
    do_unpack(data, release_path, erts_version, platform)
  end

  def get_otp_versions(platform) do
    res =
      case platform do
        :darwin -> get!(@versions_url_darwin_linux)
        :linux -> get!(@versions_url_darwin_linux)
        :win64 -> get!(@versions_url_windows)
        _ ->
          Logger.error("#{inspect(platform)} is not a valid target platform! Burrito supports :darwin, :linux, and :win64")
          exit(1)
      end

    Jason.decode!(res.body)
    |> Enum.map(fn release ->
      version = String.replace_leading(release["tag_name"], "OTP-", "")
      platform_string = Atom.to_string(platform)

      asset =
        release["assets"]
        |> Enum.find(fn asset -> String.contains?(asset["name"], platform_string) end)

      {version, asset["browser_download_url"]}
    end)
  end

  defp do_unpack(data, release_path, erts_version, :win64) do
    dest_dir = System.tmp_dir!()
    dest_path = Path.join(dest_dir, "erlang.exe")

    Logger.info("Saving win64 ERTS setup file to #{dest_path}")

    File.write!(dest_path, data.body)

    random_dir_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    extraction_path = System.tmp_dir!() |> Path.join("/erts-#{random_dir_id}")
    File.mkdir_p!(extraction_path)

    Logger.info("Extracting win64 ERTS to #{extraction_path}")

    # Use 7z to extract the Windows exe files
    ~c"7z x #{dest_path} -o#{extraction_path}" |> :os.cmd()

    dst_bin_path = Path.join(release_path, "erts-#{erts_version}/bin")
    Logger.info("Cleaning out native platform ERTS bins (#{dst_bin_path})")
    File.rm_rf!(dst_bin_path)
    File.mkdir!(dst_bin_path)

    Logger.info("Replacing ERTS bins with win64 ones...")

    src_bin_path = Path.join(extraction_path, "erts-*/bin") |> Path.wildcard() |> List.first()
    File.cp_r!(src_bin_path, dst_bin_path)

    # The ERTS comes with some pre-built NIFs, so we need to replace those .so files with a DLL
    # Glob up all the .so files in the release
    so_files = Path.join(release_path, "lib/**/*.so") |> Path.wildcard()
    src_lib_path = Path.join(extraction_path, "lib")
    dst_lib_path = Path.join(release_path, "lib")

    # If we have DLL matches for them in the ERTS directory, copy them over and delete the .so
    Enum.each(so_files, fn so ->
      possible_src_path =
        String.replace(so, dst_lib_path, src_lib_path)
        |> String.replace_suffix(".so", ".dll")

      possible_dst_path = String.replace_suffix(so, ".so", ".dll")

      if File.exists?(possible_src_path) do
        File.copy!(possible_src_path, possible_dst_path)
        File.rm!(so)
        Logger.info("Replaced NIF with DLL #{possible_src_path}")
      else
        File.rm!(so)
        Logger.warn("We couldn't find a replacement for NIF #{so}, the binary may not work!")
      end
    end)

    Logger.info("Deleting .pdb files, we don't need them...")

    # Find all debugging database files and delete them
    pdbs = Path.join(release_path, "/**/*.pdb") |> Path.wildcard()
    Enum.each(pdbs, fn p -> File.rm!(p) end)

    extraction_path
  end

  defp do_unpack(data, release_path, erts_version, :darwin) do
    dest_dir = System.tmp_dir!()
    dest_path = Path.join(dest_dir, "erlang_macos.tgz")

    Logger.info("Saving MacOS ERTS tarball to #{dest_path}")

    File.write!(dest_path, data.body)

    random_dir_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    extraction_path = System.tmp_dir!() |> Path.join("/erts-#{random_dir_id}")
    File.mkdir_p!(extraction_path)

    Logger.info("Extracting MacOS ERTS to #{extraction_path}")

    # # Use 7z to extract the MacSO files
    ~c"tar xzf #{dest_path} -C #{extraction_path}" |> :os.cmd()

    dst_bin_path = Path.join(release_path, "erts-#{erts_version}/bin")
    Logger.info("Cleaning out native platform ERTS bins (#{dst_bin_path})")
    File.rm_rf!(dst_bin_path)
    File.mkdir!(dst_bin_path)

    Logger.info("Replacing ERTS bins with MacOS ones...")

    extraction_path = Path.join(extraction_path, "otp-*/") |> Path.wildcard() |> List.first()

    src_bin_path = Path.join(extraction_path, "erts-*/bin") |> Path.wildcard() |> List.first()
    File.cp_r!(src_bin_path, dst_bin_path)

    erl_launch_path = Path.join(dst_bin_path, "erl")
    File.write!(erl_launch_path, @erl_launch_script)
    File.chmod!(erl_launch_path, 0o744)

    start_launch_path = Path.join(dst_bin_path, "start")
    File.write!(start_launch_path, @start_script)
    File.chmod!(start_launch_path, 0o744)

    # The ERTS comes with some pre-built NIFs, so we need to replace those .so files with a MacOS .so
    # Glob up all the .so files in the release
    so_files = Path.join(release_path, "lib/**/*.{so,dll}") |> Path.wildcard()
    src_lib_path = Path.join(extraction_path, "lib")
    dst_lib_path = Path.join(release_path, "lib")

    # If we have SO matches for them in the ERTS directory, copy them over and delete the other SOs
    Enum.each(so_files, fn so ->
      possible_src_path = String.replace(so, dst_lib_path, src_lib_path)

      if File.exists?(possible_src_path) do
        File.rm!(so)
        File.copy!(possible_src_path, so)
        Logger.info("Replaced NIF with MacOS SO #{possible_src_path}")
      else
        File.rm!(so)
        Logger.warn("We couldn't find a replacement for NIF #{so}, the binary may not work!")
      end
    end)

    extraction_path
  end

  defp do_unpack(data, release_path, erts_version, :linux) do
    dest_dir = System.tmp_dir!()
    dest_path = Path.join(dest_dir, "erlang_linux.tgz")

    Logger.info("Saving Linux ERTS tarball to #{dest_path}")

    File.write!(dest_path, data.body)

    random_dir_id = :crypto.strong_rand_bytes(8) |> Base.encode16()
    extraction_path = System.tmp_dir!() |> Path.join("/erts-#{random_dir_id}")
    File.mkdir_p!(extraction_path)

    Logger.info("Extracting Linux ERTS to #{extraction_path}")

    # # Use 7z to extract the linux ERTS archive
    ~c"tar xzf #{dest_path} -C #{extraction_path}" |> :os.cmd()

    dst_bin_path = Path.join(release_path, "erts-#{erts_version}/bin")
    Logger.info("Cleaning out native platform ERTS bins (#{dst_bin_path})")

    Logger.info("Replacing ERTS bins with Linux ones...")

    extraction_path = Path.join(extraction_path, "otp-*/") |> Path.wildcard() |> List.first()

    src_bin_path = Path.join(extraction_path, "erts-*/bin") |> Path.wildcard() |> List.first()
    File.cp_r!(src_bin_path, dst_bin_path)

    erl_launch_path = Path.join(dst_bin_path, "erl")
    File.write!(erl_launch_path, @erl_launch_script)
    File.chmod!(erl_launch_path, 0o744)

    start_launch_path = Path.join(dst_bin_path, "start")
    File.write!(start_launch_path, @start_script)
    File.chmod!(start_launch_path, 0o744)

    # The ERTS comes with some pre-built NIFs, so we need to replace those .so files with a linux .so
    # Glob up all the .so files in the release
    so_files = Path.join(release_path, "lib/**/*.{so,dll}") |> Path.wildcard()
    src_lib_path = Path.join(extraction_path, "lib")
    dst_lib_path = Path.join(release_path, "lib")

    # If we have SO matches for them in the ERTS directory, copy them over and delete the other SOs
    Enum.each(so_files, fn so ->
      possible_src_path = String.replace(so, dst_lib_path, src_lib_path)

      if File.exists?(possible_src_path) do
        File.rm!(so)
        File.copy!(possible_src_path, so)
        Logger.info("Replaced NIF with Linux SO #{possible_src_path}")
      else
        File.rm!(so)
        Logger.warn("We couldn't find a replacement for NIF #{so}, the binary may not work!")
      end
    end)

    extraction_path
  end
end
