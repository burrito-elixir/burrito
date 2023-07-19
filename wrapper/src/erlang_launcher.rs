/*!
    Erlang app launcher
    Computes a ton of paths required to launch an Erlang app directly
*/

use anyhow::Result;
use paris::error;
use std::fs;
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::{exit, Command};

use crate::archiver::PayloadMetadata;
use crate::errors::WrapperError;

pub fn launch_app(
    install_dir: &Path,
    release_meta: &PayloadMetadata,
    sys_args: &Vec<String>,
) -> Result<()> {
    let erl_bin_name = if cfg!(windows) { "erlexec.exe" } else { "erlexec" };

    let release_cookie_path = Path::join(install_dir, "releases/COOKIE");
    let release_lib_path = Path::join(install_dir, "lib/");
    let install_vm_args_path = buf_to_string(Path::join(
        install_dir,
        format!("releases/{}/vm.args", release_meta.app_version),
    ))?;

    let config_sys_path = buf_to_string(Path::join(
        install_dir,
        format!("releases/{}/sys.config", release_meta.app_version),
    ))?;

    let config_sys_path_no_ext = Path::join(
        install_dir,
        format!("releases/{}/sys", release_meta.app_version),
    );
    let rel_vsn_dir = Path::join(
        install_dir,
        format!("releases/{}", release_meta.app_version),
    );
    let boot_path = buf_to_string(Path::join(&rel_vsn_dir, "start"))?;

    let erts_version_name = format!("erts-{}", release_meta.erts_version);
    let erts_bin_path = Path::join(install_dir, format!("{}/bin", erts_version_name));
    let erl_bin_path = Path::join(&erts_bin_path, erl_bin_name);

    let release_cookie_file =
        fs::read_to_string(release_cookie_path).or(Err(WrapperError::LaunchCookieReadError))?;

    let mut executable = Command::new(erl_bin_path);
    executable
        .arg("-elixir ansi_enabled true")
        .arg("-noshell")
        .arg("-s elixir start_cli")
        .arg("-mode embedded")
        .arg("-setcookie")
        .arg(release_cookie_file)
        .arg("-boot")
        .arg(boot_path)
        .arg("-boot_var")
        .arg("RELEASE_LIB")
        .arg(release_lib_path)
        .arg("-args_file")
        .arg(install_vm_args_path)
        .arg("-config")
        .arg(config_sys_path);

    if cfg!(windows) {
        executable
            .env("RELEASE_ROOT", install_dir)
            .env("RELEASE_SYS_CONFIG", config_sys_path_no_ext);
    } else {
        executable
            .env("ROOTDIR", install_dir)
            .env("BINDIR", erts_bin_path)
            .env("RELEASE_ROOT", install_dir)
            .env("RELEASE_SYS_CONFIG", config_sys_path_no_ext)
            .env("EMU", "beam")
            .env("PROGNAME", "erl");
    }

    let exec_error = executable.arg("-extra").args(sys_args).exec();

    /*
    NOTE: The program should never reach this part of the code, since exec() should never actually return.
    If we have fallen to this point, it's an error.
    */

    error!("Erlang Exec Error: {}", exec_error);

    exit(1);
}

fn buf_to_string(buf: PathBuf) -> Result<String, WrapperError> {
    buf.into_os_string()
        .into_string()
        .or(Err(WrapperError::LaunchError))
}
