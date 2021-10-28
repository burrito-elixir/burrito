defmodule Burrito do
  alias Burrito.Helpers

  require Logger

  @supported_targets [:win64, :darwin, :linux]

  @success_banner """
  \n\n
  🌯 Burrito has wrapped your Elixir app! 🌯
  """

  @spec wrap(Mix.Release.t()) :: Mix.Release.t()
  def wrap(%Mix.Release{} = release) do
    options = release.options[:burrito] || []
    targets = Keyword.get(options, :targets, [:native])
    debug? = Keyword.get(options, :debug, false)
    no_clean? = Keyword.get(options, :no_clean, false)

    override_targets = maybe_get_override_targets()

    targets =
      if override_targets != [] do
        Logger.info("Override targets: #{inspect(override_targets)}")
        override_targets
      else
        targets
      end

    plugin = Keyword.get(options, :plugin, nil)

    current_system = get_current_os()

    :telemetry_sup.start_link()
    Finch.start_link(name: Req.Finch)

    Enum.each(targets, fn target ->
      if Enum.member?(@supported_targets, target) do
        # if we're building for the current host system, use a :native target
        if current_system == target do
          do_wrap(release, :native, plugin, no_clean?, debug?)
        else
          do_wrap(release, target, plugin, no_clean?, debug?)
        end
      else
        Logger.warn(
          "The target '#{inspect(target)}' is not supported, ignoring it. The supported targets are: #{string_supported_targets()}"
        )
      end
    end)

    release
  end

  defp maybe_get_override_targets do
    System.get_env("BURRITO_TARGET", "")
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn p ->
      try do
        String.to_existing_atom(p)
      rescue
        _e in ArgumentError ->
          Logger.error(
            "The override target '#{p}' is not supported! Supported targets: #{string_supported_targets()}"
          )

          exit(1)
      end
    end)
  end

  defp string_supported_targets do
    Enum.map(@supported_targets, &Atom.to_string/1) |> Enum.join(", ")
  end

  defp do_wrap(%Mix.Release{} = release, build_target, plugin, no_clean?, debug_build?) do
    # Pre-flight checks
    Helpers.Precheck.run()

    Logger.info("Burrito build target is: #{inspect(build_target)}")

    # Build potential Burrito plugin
    plugin_result = Helpers.ZigPlugins.run(plugin)

    random_build_dir_id = :crypto.strong_rand_bytes(8) |> Base.encode16()

    release_working_path =
      System.tmp_dir!() |> Path.join(["burrito_build_#{random_build_dir_id}"])

    # always overwrite files
    File.cp_r(release.path, release_working_path, fn _, _ -> true end)

    Logger.info("Build working dir: #{release_working_path}")

    erts_path =
      if build_target != :native do
        {:ok, opt_verson} =
          :file.read_file(
            :filename.join([
              :code.root_dir(),
              "releases",
              :erlang.system_info(:otp_release),
              "OTP_VERSION"
            ])
          )

        opt_verson = String.trim(opt_verson)

        Burrito.OTPFetcher.download_and_replace_erts_release(
          release.erts_version,
          opt_verson,
          release_working_path,
          build_target
        )
      end

    app_path = File.cwd!()

    # this resolves to the path in where Burrito is installed
    self_path =
      __ENV__.file
      |> Path.dirname()
      |> Path.split()
      |> List.delete_at(-1)
      |> Path.join()

    # patch up scripts for booting up the app so we can accept CLI flags
    Helpers.PatchStartupScripts.run(self_path, release_working_path, release.name)

    zig_build_args = []

    possible_cross_target =
      case build_target do
        :win64 -> "x86_64-windows-gnu"
        :darwin -> "x86_64-macos"
        :linux -> "x86_64-linux-gnu"
        _ -> ""
      end

    if possible_cross_target != "" do
      # find NIFs we probably need to recompile
      Helpers.NIFSniffer.find_nifs()
      |> Enum.each(fn dep ->
        maybe_recompile_nif(dep, release_working_path, erts_path, possible_cross_target)
      end)
    end

    # Compose final zig build args

    zig_build_args =
      if possible_cross_target != "" do
        ["-Dtarget=#{possible_cross_target}" | zig_build_args]
      else
        zig_build_args
      end

    zig_build_args =
      if debug_build? do
        zig_build_args
      else
        ["-Drelease-small=true" | zig_build_args]
      end

    release_name = Atom.to_string(release.name)

    Helpers.Metadata.run(self_path, zig_build_args, release)

    # TODO: Why do we need to do this???
    # This is to bypass a VERY strange bug inside Linux containers...
    # If we don't do this, the archiver will fail to see all the files inside the lib directory
    # This is still under investigation, but touching a file inside the directory seems to force the
    # File system to suddenly "wake up" to all the files inside it.
    Path.join(release_working_path, ["/lib", "/.burrito"]) |> File.touch!()

    build_result =
      System.cmd("zig", ["build"] ++ zig_build_args,
        cd: self_path,
        env: [
          {"__BURRITO_IS_PROD", is_prod?()},
          {"__BURRITO_RELEASE_PATH", release_working_path},
          {"__BURRITO_RELEASE_NAME", release_name},
          {"__BURRITO_PLUGIN_PATH", plugin_result}
        ],
        into: IO.stream()
      )

    orig_bin_name =
      if build_target == :win64 do
        "#{release_name}.exe"
      else
        release_name
      end

    bin_name =
      if build_target == :win64 do
        "#{release_name}_#{Atom.to_string(build_target)}.exe"
      else
        "#{release_name}_#{Atom.to_string(build_target)}"
      end

    # copy the resulting bin into the calling project's output directory
    case build_result do
      {_, 0} ->
        bin_path = Path.join(self_path, ["zig-out", "/bin", "/#{orig_bin_name}"])
        bin_out_path = Path.join(app_path, ["burrito_out"])

        File.mkdir_p!(bin_out_path)

        output_bin_path = Path.join(bin_out_path, [bin_name])

        File.copy!(bin_path, output_bin_path)
        File.rm!(bin_path)

        # Mark resulting bin as executable
        File.chmod!(output_bin_path, 0o744)

        IO.puts(@success_banner <> "\tOutput Path: #{output_bin_path}")

      _ ->
        Logger.error("Burrito failed to wrap up your app! Check the logs for more information.")
        exit(1)
    end

    # clean up everything unless asked not to
    unless no_clean? do
      Helpers.Clean.run(self_path)
      File.rm_rf!(release_working_path)
    end

    release
  end

  defp maybe_recompile_nif({_, _, false}, _, _, _), do: :no_nif

  defp maybe_recompile_nif({dep, path, true}, release_working_path, erts_path, cross_target) do
    dep = Atom.to_string(dep)

    Logger.info("Going to recompile NIF for cross-build: #{dep} -> #{cross_target}")

    _ = System.cmd("make", ["clean"], cd: path, stderr_to_stdout: true, into: IO.stream())

    erts_include = Path.join(erts_path, ["erts*", "/include"]) |> Path.wildcard() |> List.first()

    build_result =
      System.cmd("make", ["--always-make"],
        cd: path,
        stderr_to_stdout: true,
        env: [
          {"RANLIB", "zig ranlib"},
          {"AR", "zig ar"},
          {"CC", "zig cc -target #{cross_target} -v -shared"},
          {"CXX", "zig c++ -target #{cross_target} -v -shared"},
          {"CXXFLAGS", "-I#{erts_include}"},
          {"CFLAGS", "-I#{erts_include}"}
        ],
        into: IO.stream()
      )

    case build_result do
      {_, 0} ->
        Logger.info("Successfully re-built #{dep} for #{cross_target}!")

        src_priv_files = Path.join(path, ["priv/*"]) |> Path.wildcard()

        output_priv_dir =
          Path.join(release_working_path, ["lib/#{dep}*/priv"]) |> Path.wildcard() |> List.first()

        Enum.each(src_priv_files, fn file ->
          file_name = Path.basename(file)
          dst_fullpath = Path.join(output_priv_dir, file_name)

          Logger.info("#{file} -> #{output_priv_dir}")

          File.copy!(file, dst_fullpath)
        end)

      {output, _} ->
        Logger.error("Failed to rebuild #{dep} for #{cross_target}!")
        Logger.error(output)
        exit(1)
    end
  end

  defp get_current_os do
    case :os.type() do
      {:win32, _} -> :windows
      {:unix, :darwin} -> :darwin
      {:unix, :linux} -> :linux
    end
  end

  defp is_prod?() do
    if Mix.env() == :prod do
      "1"
    else
      "0"
    end
  end
end
