/////
// This is a packing/unpacking utility used to pack up a elixir mix release into "FOILZ" archive.
// The structure of the FOILZ archive file is very simple, and akin to a very basic TAR archive:
//
//                           ┌────────────────────────┐
//                           │                        │
//                           │  Magic Header: 'FOILZ' │
//                           │                        │
//                           ├────────────────────────┤
//                 ┌──────── │  u64  File Path Len    │◄───────── Informs how long the string following will be
//                 │         ├────────────────────────┤
//                 │         │                        │
//                 │         │  File Path Characters  │◄───────── File path in release dir + file name
// File Record ────┤         │                        │
//                 │         ├────────────────────────┤
//                 │         │  u64  File Byte Len    │◄───────── Informs how long the file bytes following will be
//                 │         ├────────────────────────┤
//                 │         │                        │
//                 │         │       File Bytes       │◄───────── Raw bytes of file
//                 │         │                        │
//                 │         ├────────────────────────┤
//                 └──────── │   usize   File Mode    │◄───────── POSIX File Mode (Ignored on Windows)
//                           ├────────────────────────┤
//                           │                        │
//                           │ Magic Trailer: 'FOILZ' │
//                           │                        │
//                           └────────────────────────┘
//
// There can be many file records inside a FOILZ archive, after packing, it is gzip or xz compressed.
// At runtime, we decompress it in memory and write the files to disk in a common location.
/////

const builtin = @import("builtin");
const std = @import("std");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const fs = std.fs;
const log = std.log;
const mem = std.mem;
const os = std.os;
const gzip = std.compress.gzip;

const xz = @cImport(@cInclude("xz.h"));

const MAGIC = "FOILZ";
const MAX_READ_SIZE = 1000000000;

pub fn pack_directory(arena: Allocator, path: []const u8, archive_path: []const u8) anyerror!void {
    // Open a file for the archive
    const arch_file = try fs.cwd().createFile(archive_path, .{ .truncate = true });
    defer arch_file.close();

    var foilz_write_buf: [1024]u8 = undefined;
    var foilz_writer = arch_file.writer(&foilz_write_buf);
    const writer = &foilz_writer.interface;

    var dir = try fs.openDirAbsolute(path, .{ .access_sub_paths = true, .iterate = true });
    defer dir.close();

    var walker = try dir.walk(arena);
    defer walker.deinit();

    var count: u32 = 0;

    try writer.writeAll(MAGIC);

    while (try walker.next()) |entry| {
        if (entry.kind == .file) {
            // Replace some path string data for the tar index name
            // specifically replace: '../_build/prod/rel/' --> ''
            // This just makes it easier to write the files out later on the destination machine
            const needle = path;
            const replacement = "";
            const replacement_size = mem.replacementSize(u8, entry.path, needle, replacement);
            var dest_buff: [fs.max_path_bytes]u8 = undefined;
            const index = dest_buff[0..replacement_size];
            _ = mem.replace(u8, entry.path, needle, replacement, index);

            const file = try entry.dir.openFile(entry.basename, .{});
            defer file.close();

            var read_buf: [1024]u8 = undefined;
            var file_reader = file.reader(&read_buf);
            const reader = &file_reader.interface;

            const stat = try file.stat();

            // Write file record to archive
            const name = index;
            try writer.writeInt(u64, name.len, .little);
            try writer.writeAll(name);
            try writer.writeInt(u64, stat.size, .little);
            if (stat.size > 0) {
                assert(stat.size == try reader.streamRemaining(writer));
            }
            try writer.writeInt(usize, stat.mode, .little);

            count += 1;

            direct_log("\rinfo: 🔍 Files Packed: {}", .{count});
        }
    }
    direct_log("\n", .{});

    // Log success

    try writer.writeAll(MAGIC);
    try writer.flush();

    log.info("Archived {} files into payload! 📥", .{count});
}

pub fn unpack_files(arena: Allocator, data: []const u8, dest_path: []const u8, uncompressed_size: u64) !void {
    // Decompress the data in the payload

    var decompressed: []u8 = try arena.alloc(u8, uncompressed_size);

    var xz_buffer: xz.xz_buf = .{
        .in = data.ptr,
        .in_size = data.len,
        .out = decompressed.ptr,
        .out_size = uncompressed_size,
        .in_pos = 0,
        .out_pos = 0,
    };

    xz.xz_crc32_init();
    const status = xz.xz_dec_init(xz.XZ_SINGLE, 0);
    const ret = xz.xz_dec_run(status, &xz_buffer);
    xz.xz_dec_end(status);

    if (ret != xz.XZ_STREAM_END) {
        std.log.err("XZ/LZMA Decode Failed: {}", .{ret});
        return error.ParseError;
    }

    // Validate the header of the payload
    if (!std.mem.eql(u8, MAGIC, decompressed[0..5])) {
        return error.BadHeader;
    }

    // We start at position 5 to skip the header
    var cursor: u64 = 5;
    var file_count: u64 = 0;

    //////
    // Read until we reach the end of the trailer
    // Look ahead 5 bytes and see
    while (cursor < decompressed.len - 5) {
        //////
        // Read the file name
        const string_len = std.mem.readInt(u64, decompressed[cursor .. cursor + @sizeOf(u64)][0..8], .little);
        cursor = cursor + @sizeOf(u64);

        const file_name = decompressed[cursor .. cursor + string_len];
        cursor = cursor + string_len;

        //////
        // Read the file data from the payload
        const file_len = std.mem.readInt(u64, decompressed[cursor .. cursor + @sizeOf(u64)][0..8], .little);
        cursor = cursor + @sizeOf(u64);

        const file_data = decompressed[cursor .. cursor + file_len];
        cursor = cursor + file_len;

        //////
        // Read the mode for this file
        const file_mode = std.mem.readInt(usize, decompressed[cursor .. cursor + @sizeOf(usize)][0..@sizeOf(usize)], .little);
        cursor = cursor + @sizeOf(usize);

        //////
        // Write the file
        const full_file_path = try fs.path.join(arena, &[_][]const u8{ dest_path[0..], file_name });

        //////
        // Create any directories needed
        const dir_name = fs.path.dirname(file_name);
        if (dir_name != null) try create_dirs(dest_path[0..], dir_name.?, arena);

        log.debug("Unpacked File: {s}", .{full_file_path});

        //////
        // Write the file to disk!

        // If we're on windows don't try and use file_mode because NTFS doesn't have that!
        if (builtin.os.tag == .windows) {
            const file = try fs.createFileAbsolute(full_file_path, .{ .truncate = true });
            if (file_len > 0) {
                try file.writeAll(file_data);
            }
            file.close();
        } else {
            const file = try fs.createFileAbsolute(full_file_path, .{ .truncate = true, .mode = @intCast(file_mode) });
            if (file_len > 0) {
                try file.writeAll(file_data);
            }
            file.close();
        }

        file_count = file_count + 1;
    }

    log.debug("Unpacked {} files", .{file_count});
}

fn create_dirs(dest_path: []const u8, sub_dir_names: []const u8, allocator: Allocator) !void {
    var iterator = try fs.path.componentIterator(sub_dir_names);
    var full_dir_path = try fs.path.join(allocator, &[_][]const u8{ dest_path, "" });

    while (iterator.next()) |sub_dir| {
        full_dir_path = try fs.path.join(allocator, &[_][]const u8{ full_dir_path, sub_dir.name });
        fs.makeDirAbsolute(full_dir_path) catch |err| {
            switch (err) {
                error.PathAlreadyExists => {
                    log.debug("Directory Exists: {s}", .{full_dir_path});
                    continue;
                },
                else => return err,
            }
        };
        log.debug("Created Directory: {s}", .{full_dir_path});
    }
}

// Adapted from `std.log`, but without forcing a newline
fn direct_log(comptime message: []const u8, args: anytype) void {
    var buffer: [64]u8 = undefined;
    const stderr = std.debug.lockStderrWriter(&buffer);
    defer std.debug.unlockStderrWriter();
    nosuspend {
        stderr.print(message, args) catch return;
        stderr.flush() catch return;
    }
}
