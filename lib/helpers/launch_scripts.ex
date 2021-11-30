defmodule Burrito.Helpers.LauncScripts do
  require Logger

  def copy_launch_scripts(self_path, release_path, release_name) do
    Logger.info("Copying Burrito startup scripts for release...")

    # Copy over the app startup scripts for all platforms
    shell_path = Path.join(self_path, ["/src", "/scripts", "/posix_start.sh"])
    bat_path = Path.join(self_path, ["/src", "/scripts", "/win_start.bat"])

    bin_path = Path.join(release_path, ["/bin"])
    dest_shell_path = Path.join(bin_path, ["/#{release_name}"])
    dest_bat_path = Path.join(bin_path, ["/#{release_name}.bat"])

    File.copy!(shell_path, dest_shell_path)
    File.copy!(bat_path, dest_bat_path)

    File.chmod!(dest_shell_path, 0o744)

    # Copy over POSIX "erl" and "start" scripts into the ERTS bin directory

    dst_bin_path = Path.join(release_path, "erts-*/bin") |> Path.wildcard() |> List.first()

    erl_script_path = Path.join(self_path, ["/src", "/scripts", "/posix_erl.sh"])
    start_script_path = Path.join(self_path, ["/src", "/scripts", "/posix_erts_start.sh"])

    erl_launch_dest_path = Path.join(dst_bin_path, "erl")
    File.copy!(erl_script_path, erl_launch_dest_path)
    File.chmod!(erl_launch_dest_path, 0o744)

    start_launch_dest_path = Path.join(dst_bin_path, "start")
    File.copy!(start_script_path, start_launch_dest_path)
    File.chmod!(start_launch_dest_path, 0o744)
  end
end
