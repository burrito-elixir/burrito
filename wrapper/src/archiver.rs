use std::{io::Cursor, path::Path};
use walkdir::WalkDir;
use binrw::{binrw, BinWrite, NullString};
use serde::{Deserialize, Serialize};

#[binrw]
pub struct FoilzFileRecord {
    pub file_path: NullString,
    pub file_size: u64,
    #[br(count = file_size)]
    pub file_data: Vec<u8>,
    pub file_mode: u32,
}

#[binrw]
#[brw(magic = b"FOILZ")]
pub struct FoilzPayload {
    pub num_files: u32,
    #[br(count = num_files)]
    pub files: Vec<FoilzFileRecord>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct PayloadMetadata {
    pub app_name: String,
    pub app_version: String,
    pub cargo_build_arguments: Vec<String>,
    pub erts_version: String,
    pub options: String,
    pub rust_version: String,
}

// This isn't actually dead code, it's used by the build.rs script!
#[allow(dead_code)]
pub fn pack_directory(path: &Path) -> Vec<u8> {
    let mut file_records: Vec<FoilzFileRecord> = Vec::new();
    // Walk over the source directory recursively
    for entry in WalkDir::new(path) {
        // Ensure we have a valid entry, then ensure it's a file
        match entry {
            Ok(dir_entry) => {
                if dir_entry.path().is_file() {
                    // Create file record
                    match create_file_record(dir_entry.path(), path) {
                        Some(new_record) => {
                            file_records.push(new_record);
                        }
                        None => continue,
                    }
                }
            }
            Err(e) => {
                panic!("Error reading directory entry: {e}");
            }
        }
    }

    // Construct the final payload struct
    let final_payload = FoilzPayload {
        num_files: file_records.len() as u32,
        files: file_records,
    };

    let mut writer = Cursor::new(Vec::new());
    final_payload
        .write_be(&mut writer)
        .expect("Failed to serialize payload struct!");
    writer.into_inner().to_owned()
}

// This isn't actually dead code, it's used by the build.rs script!
#[allow(dead_code)]
fn create_file_record(file_path: &Path, top_path: &Path) -> Option<FoilzFileRecord> {
    match (std::fs::metadata(file_path), std::fs::read(file_path)) {
        (Ok(file_metadata), Ok(file_content)) => {

            #[cfg(windows)]
            let file_mode = 0;

            #[cfg(unix)]
            let file_mode = std::os::unix::prelude::PermissionsExt::mode(&file_metadata.permissions());

            let file_path = String::from(file_path.to_str()?)
                .replace(top_path.to_str()?, "")
                .replacen("/", "", 1);
            return Some(FoilzFileRecord {
                file_path: NullString::from(file_path),
                file_size: file_content.len() as u64,
                file_data: file_content,
                file_mode: file_mode,
            });
        }
        _ => None,
    }
}
