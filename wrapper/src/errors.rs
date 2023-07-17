use thiserror::Error;

#[derive(Error, Debug)]
pub enum WrapperError {
    // Errors relating to the payload extraction
    #[error("Failed to decompress the payload, it may be damaged!")]
    PayloadDecompressFailed,
    #[error("Could not create the destination directory for the file: {0}")]
    ExtractMkdirFailed(String),
    #[error("Could not write the file: {0}")]
    ExtractFileWriteFailed(String),
    #[error("Failed to set the permissions/mode on file: {0}")]
    ExtractChmodFailed(String),
    #[error("Invalid installation directory")]
    ExtractInvalidInstallDir,
    #[error("We could not compute a valid installation directory, your platform may not be supported!")]
    ExtractCannotComputeInstallDir,

    // Metadata related errors
    #[error("Metadata JSON is corrupted!")]
    MetadataCorrupted,

    // Erlang launcher related errors
    #[error("Could not read the COOKIE file for the release!")]
    LaunchCookieReadError,
    #[error("Erlang launcher error. Please file an issue with the Burrito project.")]
    LaunchError
}
