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
    const options = .{ .allocator = allocator };
    var token_stream = std.json.TokenStream.init(string_data);
    const metadata_parsed = std.json.parse(MetaStruct, &token_stream, options) catch |e| {
        std.log.err("Error when parsing metadata: {!}", .{e});
        return null;
    };

    return metadata_parsed;
}
