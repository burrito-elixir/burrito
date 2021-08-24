defmodule Burrito.Helpers.PatchStartupScripts do
  require Logger

  def run(self_path, release_path, release_name) do
    Logger.info("Patching shell script for release...")

    shell_patch_path = Path.join(self_path, ["/src", "/pass_args_patch_posix.diff"])
    bat_patch_path = Path.join(self_path, ["/src", "/pass_args_patch_win.diff"])

    shell_path = Path.join(release_path, ["/bin", "/#{release_name}"])
    bat_path = Path.join(release_path, ["/bin", "/#{release_name}.bat"])

    System.cmd("patch", [shell_path, shell_patch_path])
    System.cmd("patch", [bat_path, bat_patch_path])
  end
end
