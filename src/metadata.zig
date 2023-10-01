const std = @import("std");

pub const MetaStruct = struct {
    app_name: []const u8 = undefined,
    zig_version: []const u8 = undefined,
    zig_build_arguments: []const []const u8 = undefined,
    app_version: []const u8 = undefined,
    options: []const u8 = undefined,
    erts_version: []const u8 = undefined,
};

pub fn parse(allocator: std.mem.Allocator, string_data: []const u8) ?MetaStruct {
    const metadata_parsed = std.json.parseFromSlice(MetaStruct, allocator, string_data, .{}) catch |e| {
        std.log.err("Error when parsing metadata: {!}", .{e});
        return null;
    };

    return metadata_parsed.value;
}
