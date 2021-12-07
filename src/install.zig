const std = @import("std");
const metadata = @import("metadata.zig");
const MetaStruct = metadata.MetaStruct;

const MAX_READ_SIZE = 1000000000;

pub const Install = struct {
    metadata_file_path: []const u8 = undefined,
    base_install_dir_path: []const u8 = undefined,
    install_dir_path: []const u8 = undefined,
    metadata: MetaStruct = undefined,
    version: std.SemanticVersion = undefined,
};

pub fn load_install_from_path(allocator: std.mem.Allocator, full_install_path: []const u8) !?Install {
    const metadata_file_path = try std.fs.path.join(allocator, &[_][]const u8{ full_install_path, "_metadata.json" });
    const metadata_file = std.fs.openFileAbsolute(metadata_file_path, .{}) catch {
        std.log.err("Failed to load the metadata file: {s}", .{metadata_file_path});
        return null;
    };

    defer metadata_file.close();

    const content = try metadata_file.readToEndAlloc(allocator, MAX_READ_SIZE);
    const metadata_struct = metadata.parse(allocator, content);

    if (metadata_struct == null) {
        std.log.err("Failed to parse metadata file: {s}", .{metadata_file_path});
        return null;
    }

    const parsed_version = std.SemanticVersion.parse(metadata_struct.?.app_version) catch {
        std.log.err("Failed to parse the app version: {s}", .{metadata_file_path});
        return null;
    };

    return Install{
        .metadata_file_path = metadata_file_path,
        .base_install_dir_path = full_install_path,
        .install_dir_path = full_install_path,
        .metadata = metadata_struct.?,
        .version = parsed_version,
    };
}
