use std::{env, path::{Path, PathBuf}, fs};

#[path = "src/archiver.rs"]
mod archiver;

fn main() {
    // This is a hack to get around local development, if you're working in an IDE/Editor
    // That's using the rust-analyzer, it'll rebuild the payload over and over, so this forces it to skip
    // the payload pack and compress entirely.
    if get_env_variable("__BURRITO") != "1" {
        set_release_env(false, "empty".to_owned(), "{}".to_owned());
        return;
    }

    // This build script uses the data passed in via env variable via Burrito to build and pack the release
    let release_path_string: String = get_env_variable("__BURRITO_RELEASE_PATH");
    let release_name: String = get_env_variable("__BURRITO_RELEASE_NAME");
    // let plugin_path_string: String = get_env_variable("__BURRITO_PLUGIN_PATH");
    let is_prod: bool = get_env_variable("__BURRITO_IS_PROD") == "1";

    // Construct payload path
    let release_path: &Path = Path::new(&release_path_string);
    let payload_name: &Path = Path::new("./payload.foilz.xz");

    // Attempt to build the payload
    let mut payload_bytes = archiver::pack_directory(release_path);
    let metadata_string = read_metadata(release_path);

    // Compress bytes
    let mut compressor = snap::raw::Encoder::new();

    match compressor.compress_vec(&mut payload_bytes) {
        Ok(compressed) => {
            match fs::write(payload_name, compressed) {
                Ok(_) => println!("Payload complete!"),
                Err(e) => {
                    panic!("Failed to write payload to disk: {e}");
                }
            }
        }
        Err(e) => {
            panic!("Failed to compress payload: {e}");
        }
    }

    set_release_env(is_prod, release_name, metadata_string);
}

fn get_env_variable(key: &str) -> String {
    match env::var(key) {
        Ok(val) => val,
        Err(_e) => {
            "".to_owned()
        }
    }
}

fn set_release_env(is_prod: bool, release_name: String, metedata: String) {
    if is_prod {
        println!("cargo:rustc-env=IS_PROD=1");
    }
    
    println!("cargo:rustc-env=RELEASE_NAME={release_name}");
    println!("cargo:rustc-env=RELEASE_METADATA={metedata}");
}

fn read_metadata(release_path: &Path) -> String {
    let mut full_path: PathBuf = release_path.clone().to_path_buf();
    full_path.push("_metadata.json");
    fs::read_to_string(full_path).expect("Failed to read metadata file!")
}
