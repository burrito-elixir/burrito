use thiserror::Error;

#[derive(Error, Debug)]
pub enum WrapperError {
    #[error("Error parsing metadata: {0}")]
    ParseMetadataError(MetadataError),

    #[error("Error computing the base install directory: {0}")]
    ComputeInstallDirectoryError(ExtractError),

    #[error("Error unpacking payload: {0}")]
    DecompressPayloadError(ExtractError),

    #[error("Failed to launch inner application: {0}")]
    LaunchError(LauncherError),
}

// Errors relating to the payload extraction
#[derive(Error, Debug)]
pub enum ExtractError {
    #[error("Failed to decompress the payload, it may be damaged!")]
    PayloadDecompressError,
    #[error("Failed to parse the decompressed payload, it may be damaged!")]
    PayloadParseError,
    #[error("Could not create the destination directory for the file: {0}")]
    MkdirError(std::io::Error),
    #[error("Could not create file: {0}")]
    FileCreateError(std::io::Error),
    #[error("Could not write data to file: {0}")]
    FileWriteError(std::io::Error),
    #[error("Failed to set the permissions/mode on file: {0}")]
    ChmodError(std::io::Error),
    #[error("Invalid installation directory")]
    InvalidInstallDirError,
    #[error(
        "Could not compute a valid installation directory, your platform may not be supported!"
    )]
    CannotComputeInstallDirError,
}

// Errors relating to metadata validation
#[derive(Error, Debug)]
pub enum MetadataError {
    // Metadata related errors
    #[error("Metadata JSON is corrupted!")]
    CorruptedError,
}

// Erlang launcher related errors
#[derive(Error, Debug)]
pub enum LauncherError {
    #[error("Could not read the COOKIE file for the release!")]
    CookieReadError,
    #[error("Erlang launcher error. Please file an issue with the Burrito project.")]
    EncodingError,
    #[error("Erlang exec error: {0}")]
    ErlangError(std::io::Error),
    #[error("Could not launch the application, your host platform is not supported!")]
    UnsupportedPlatformError,
}
