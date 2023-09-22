/*!
    Erlang app launcher
    Computes a ton of paths required to launch an Erlang app directly
*/

use anyhow::Result;

#[cfg(unix)]
use std::os::unix::process::CommandExt;

use std::path::PathBuf;
use std::process::{abort, exit, Command};

use crate::errors::LauncherError;
use crate::release::Release;

pub fn launch_app(release: &Release, sys_args: &Vec<String>) -> Result<(), LauncherError> {
    let erl_bin_path = buf_to_string("erl bin path", release.erl_bin_path())?;
    let release_cookie_file = release.load_cookie_file()?;
    let boot_path = buf_to_string("boot path", release.boot_path())?;
    let release_lib_path = buf_to_string("release lib path", release.lib_path())?;
    let install_vm_args_path = buf_to_string("vm args path", release.install_vm_args_path())?;
    let config_sys_path = buf_to_string("config sys path", release.config_sys_path())?;
    let install_dir = buf_to_string("install directory", release.install_dir())?;
    let config_sys_path_no_ext =
        buf_to_string("config sys path", release.config_sys_path_no_ext())?;
    let erts_bin_path = buf_to_string("erts bin path", release.erts_bin_path())?;

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

    executable
        .env("RELEASE_ROOT", &install_dir)
        .env("RELEASE_SYS_CONFIG", config_sys_path_no_ext);

    if !cfg!(windows) {
        executable
            .env("ROOTDIR", &install_dir)
            .env("BINDIR", erts_bin_path)
            .env("EMU", "beam")
            .env("PROGNAME", "erl");
    }

    executable.arg("-extra").args(sys_args);

    if cfg!(unix) {
        handle_unix_exec(&mut executable)
    } else if cfg!(windows) {
        handle_windows_exec(&mut executable)
    } else {
        Err(LauncherError::UnsupportedPlatformError)
    }
}

fn handle_unix_exec(executable: &mut Command) -> Result<(), LauncherError> {
    let exec_error = executable.exec();
    Err(LauncherError::ErlangError(exec_error))
}

fn handle_windows_exec(executable: &mut Command) -> Result<(), LauncherError> {
    let mut child_process = executable.spawn()?;
    let exit_status = child_process.wait()?;

    match exit_status.code() {
        Some(code) => exit(code),
        None => abort(),
    }
}

fn buf_to_string(name: &str, buf: PathBuf) -> Result<String, LauncherError> {
    buf.into_os_string()
        .into_string()
        .map_err(|_| LauncherError::EncodingError(name.to_string()))
}
