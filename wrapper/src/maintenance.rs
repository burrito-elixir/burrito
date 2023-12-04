use crate::console::{confirm, info, warn, IO};
use crate::errors::ReleaseError;
use crate::release;
use crate::release::Release;

pub fn print_metadata<I: IO>(io: &mut I) {
    info!(io, "{}", release::RELEASE_METADATA_STR);
}

pub fn print_install_dir<I: IO>(io: &mut I) -> Result<(), ReleaseError> {
    let install_dir = Release::load(io)?.install_dir();

    info!(io, "<path>{}</>", install_dir.display());

    Ok(())
}

pub fn uninstall<I: IO>(io: &mut I) -> Result<(), ReleaseError> {
    let install_dir = Release::load(io)?.install_dir();

    warn!(
        io,
        "This will uninstall the application runtime for this Burrito binary!"
    );

    warn!(io, "Second thingy!");

    // if confirm!(
    //     io,
    //     "Delete runtime at <path>`{}`</>?",
    //     install_dir.display()
    // ) {
    //     info!(io, "<destructive>Deleting `{}`</>", install_dir.display());
    // }

    Ok(())
}

pub fn clean_old_versions<I: IO>(io: &mut I) {
    info!(io, "Cleaning up old versions of this application...");
}
