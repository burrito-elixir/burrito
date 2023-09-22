use thiserror::Error;

#[derive(Error, Debug)]
pub enum WrapperError {
    #[error("Failed to load release information: {0}")]
    LoadReleaseError(#[from] ReleaseError),

    #[error("Failed to unpack payload: {0}")]
    DecompressPayloadError(#[from] ExtractError),

    #[error("Failed to launch inner application: {0}")]
    LaunchError(#[from] LauncherError),
}

// Errors relating to the payload extraction
#[derive(Error, Debug)]
pub enum ExtractError {
    #[error("Could not decompress the payload, it may be damaged!")]
    PayloadDecompressError,
    #[error("Could not parse the decompressed payload, it may be damaged!")]
    PayloadParseError,
    #[error("Could not create the destination directory for the file: {0}")]
    MkdirError(std::io::Error),
    #[error("Could not create file: {0}")]
    FileCreateError(std::io::Error),
    #[error("Could not write data to file: {0}")]
    FileWriteError(std::io::Error),
    #[error("Could not set the permissions/mode on file: {0}")]
    ChmodError(std::io::Error),
    #[error("Invalid installation directory")]
    InvalidInstallDirError,
}

// Errors relating to parsing releases and release paths
#[derive(Error, Debug)]
pub enum ReleaseError {
    #[error(
        "Could not compute a valid installation directory, your platform may not be supported!"
    )]
    ComputeInstallDirError,
    #[error("Could not read the COOKIE file for the release!")]
    CookieReadError,
    #[error("Metadata JSON is corrupted!")]
    CorruptedMetadataError,
}

// Erlang launcher related errors
#[derive(Error, Debug)]
pub enum LauncherError {
    #[error("Erlang exec error: {0}")]
    ErlangError(#[from] std::io::Error),
    #[error("Invalid encoding in {0}")]
    EncodingError(String),
    #[error("Could not launch the application, your host platform is not supported!")]
    UnsupportedPlatformError,
    #[error("Could not load wrapper information: {0}")]
    LoadReleaseError(#[from] ReleaseError),
}
