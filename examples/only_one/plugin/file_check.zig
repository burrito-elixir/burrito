const std = @import("std");
const File = std.fs.File;

pub fn burrito_plugin_entry(install_dir: []const u8, program_manifest_json: []const u8) void {
    std.debug.print("Zig Plugin Init!\n", .{});
    std.debug.print("Install Dir: {s}\n", .{install_dir});
    std.debug.print(": {s}\n", .{program_manifest_json});

    const exists = if (std.fs.cwd().access("only_one.lock", .{ .mode = File.OpenMode.read_only })) true else |_| false;

    if (exists) {
        std.log.err("We found a lockfile! Can't run two of this application at one!\n", .{});
        std.process.exit(0);
    }
}
