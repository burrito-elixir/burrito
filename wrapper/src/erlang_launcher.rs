/*!
    Erlang app launcher
    Computes a ton of paths required to launch an Erlang app directly
*/

use anyhow::Result;
use std::fs;

#[cfg(unix)]
use std::os::unix::process::CommandExt;

use std::path::{Path, PathBuf};
use std::process::{abort, exit, Command};

use crate::archiver::PayloadMetadata;
use crate::errors::WrapperError;

macro_rules! build_path {
    ($root:expr,$path:expr) => {
        buf_to_string($root.join($path))
    };
    ($root:expr, $pattern:expr, $($value:expr),+) => {
        buf_to_string($root.join(format!($pattern, $($value),+)))
    };
}

pub fn launch_app(
    install_dir: &Path,
    release_meta: &PayloadMetadata,
    sys_args: &Vec<String>,
) -> Result<(), WrapperError> {
    let erl_bin_name = if cfg!(windows) { "erl.exe" } else { "erlexec" };

    let release_cookie_path = build_path!(install_dir, "releases/COOKIE")?;
    let release_lib_path = build_path!(install_dir, "lib/")?;

    let install_vm_args_path =
        build_path!(install_dir, "releases/{}/vm.args", release_meta.app_version)?;

    let config_sys_path = build_path!(
        install_dir,
        "releases/{}/sys.config",
        release_meta.app_version
    )?;

    let config_sys_path_no_ext =
        build_path!(install_dir, "releases/{}/sys", release_meta.app_version)?;

    let boot_path = build_path!(install_dir, "releases/{}/start", release_meta.app_version)?;

    let erts_version_name = format!("erts-{}", release_meta.erts_version);
    let erts_bin_path = build_path!(install_dir, "{}/bin", erts_version_name)?;
    let erl_bin_path = build_path!(install_dir, "{}/bin/{}", erts_version_name, erl_bin_name)?;

    let release_cookie_file =
        fs::read_to_string(release_cookie_path).map_err(|_| WrapperError::LaunchCookieReadError)?;

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
        .env("RELEASE_ROOT", install_dir)
        .env("RELEASE_SYS_CONFIG", config_sys_path_no_ext);

    if !cfg!(windows) {
        executable
            .env("ROOTDIR", install_dir)
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
        Err(WrapperError::LaunchUnsupportedPlatformError)
    }
}

fn handle_unix_exec(executable: &mut Command) -> Result<(), WrapperError> {
    let exec_error = executable.exec();
    Err(WrapperError::LaunchErlangError(exec_error))
}

fn handle_windows_exec(executable: &mut Command) -> Result<(), WrapperError> {
    executable
        .spawn()
        .and_then(|mut child_process| child_process.wait())
        .map(|exit_status| match exit_status.code() {
            Some(code) => exit(code),
            None => abort(),
        })
        .map_err(|exec_error| WrapperError::LaunchErlangError(exec_error))
}

fn buf_to_string(buf: PathBuf) -> Result<String, WrapperError> {
    buf.into_os_string()
        .into_string()
        .map_err(|_| WrapperError::LaunchEncodingError)
}
