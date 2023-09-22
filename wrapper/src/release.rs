use std::path::{Path, PathBuf};
use std::{env, fs};

use crate::archiver::PayloadMetadata;
use crate::errors::ReleaseError;

use paris::info;

pub const INSTALL_SUFFIX: &str = ".burrito";

macro_rules! build_path {
  ($root:expr, $path:expr) => {
      $root.join($path)
  };
  ($root:expr, $pattern:expr, $($value:expr),+) => {
      $root.join(format!($pattern, $($value),+))
  };
}

pub struct Release {
    release_meta: PayloadMetadata,
    install_dir: PathBuf,
}

impl Release {
    pub fn new(release_name: &str, release_metadata_str: &str) -> Result<Release, ReleaseError> {
        let release_meta = parse_metadata(release_metadata_str)?;
        let install_dir = calculate_install_dir(release_name, &release_meta)?;

        Ok(Release {
            release_meta: release_meta,
            install_dir: install_dir,
        })
    }

    pub fn cookie_path(&self) -> PathBuf {
        build_path!(self.install_dir, "releases/COOKIE")
    }

    pub fn lib_path(&self) -> PathBuf {
        build_path!(self.install_dir, "lib/")
    }

    pub fn install_vm_args_path(&self) -> PathBuf {
        build_path!(
            self.install_dir,
            "releases/{}/vm.args",
            self.release_meta.app_version
        )
    }

    pub fn config_sys_path(&self) -> PathBuf {
        build_path!(
            self.install_dir,
            "releases/{}/sys.config",
            self.release_meta.app_version
        )
    }

    pub fn config_sys_path_no_ext(&self) -> PathBuf {
        build_path!(
            self.install_dir,
            "releases/{}/sys",
            self.release_meta.app_version
        )
    }

    pub fn boot_path(&self) -> PathBuf {
        build_path!(
            self.install_dir,
            "releases/{}/start",
            self.release_meta.app_version
        )
    }

    pub fn erts_version_name(&self) -> String {
        format!("erts-{}", self.release_meta.erts_version)
    }

    pub fn erts_bin_path(&self) -> PathBuf {
        build_path!(self.install_dir, "{}/bin", self.erts_version_name())
    }

    pub fn erl_bin_name(&self) -> &str {
        if cfg!(windows) {
            "erl.exe"
        } else {
            "erlexec"
        }
    }

    pub fn erl_bin_path(&self) -> PathBuf {
        build_path!(
            self.install_dir,
            "{}/bin/{}",
            self.erts_version_name(),
            self.erl_bin_name()
        )
    }

    pub fn load_cookie_file(&self) -> Result<String, ReleaseError> {
        let cookie_path = self.cookie_path();

        fs::read_to_string(cookie_path).map_err(|_| ReleaseError::CookieReadError)
    }

    pub fn install_dir(&self) -> PathBuf {
        self.install_dir.clone()
    }
}

fn calculate_install_dir(
    release_name: &str,
    release_meta: &PayloadMetadata,
) -> Result<PathBuf, ReleaseError> {
    let install_dir_env_name = format!("{}_INSTALL_PATH", release_name);

    let release_suffix = format!(
        "{}_erts-{}_{}",
        release_name, release_meta.erts_version, release_meta.app_version
    );

    let possible_env_override = env::var(install_dir_env_name).map(|path_override| {
        info!(
            "Install path is being overridden using env var: {}_INSTALL_PATH",
            release_name
        );
        info!("New install path is: {}", path_override);

        Path::new(&path_override).to_path_buf()
    });

    let fallback_to_default_base_dir =
        |_| dirs::data_dir().ok_or(ReleaseError::ComputeInstallDirError);

    let mut path = possible_env_override.or_else(fallback_to_default_base_dir)?;

    path.push(INSTALL_SUFFIX);
    path.push(release_suffix);
    Ok(path)
}

fn parse_metadata(release_metadata_str: &str) -> Result<PayloadMetadata, ReleaseError> {
    serde_json::from_str(release_metadata_str).map_err(|_| ReleaseError::CorruptedMetadataError)
}
