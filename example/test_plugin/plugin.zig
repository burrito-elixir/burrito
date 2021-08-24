const std = @import("std");

pub fn burrito_plugin_entry(install_dir: []const u8, program_manifest_json: []const u8) void {
    std.log.info("Test Plugin Init!", .{});
    std.log.info("Test Plugin: {s}", .{install_dir});
    std.log.info("Test Plugin: {s}", .{program_manifest_json});
}
