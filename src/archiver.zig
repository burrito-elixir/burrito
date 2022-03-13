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
//                 └──────── │  u64   File Mode       │◄───────── POSIX File Mode (Ignored on Windows)
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

const fs = std.fs;
const log = std.log;
const mem = std.mem;
const os = std.os;
const gzip = std.compress.gzip;

const xz = @cImport(@cInclude("xz.h"));

const MAGIC = "FOILZ";
const MAX_READ_SIZE = 1000000000;

pub fn pack_directory(path: []const u8, archive_path: []const u8) anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Open a file for the archive
    _ = try fs.cwd().createFile(archive_path, .{ .truncate = true });
    const arch_file = try fs.cwd().openFile(archive_path, .{ .write = true });
    const foilz_writer = fs.File.writer(arch_file);

    var dir = try fs.openDirAbsolute(path, .{ .iterate = true });
    var walker = try dir.walk(allocator);

    var count: u32 = 0;

    try write_magic_number(&foilz_writer);

    while (try walker.next()) |entry| {
        if (entry.kind == .File) {
            // Replace some path string data for the tar index name
            // specifically replace: '../_build/prod/rel/' --> ''
            // This just makes it easier to write the files out later on the destination machine
            const needle = path;
            const replacement = "";
            const replacement_size = mem.replacementSize(u8, entry.path, needle, replacement);
            var dest_buff: [fs.MAX_PATH_BYTES]u8 = undefined;
            const index = dest_buff[0..replacement_size];
            _ = mem.replace(u8, entry.path, needle, replacement, index);

            // Read the entire contents of the file into a buffer
            const file = try entry.dir.openFile(entry.basename, .{});
            defer file.close();

            // Allocate memory for the file
            var file_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer file_arena.deinit();
            var file_allocator = file_arena.allocator();

            // Read the file
            const file_buffer = try file.readToEndAlloc(file_allocator, MAX_READ_SIZE);
            const stat = try file.stat();

            // Write file record to archive
            try write_file_record(&foilz_writer, index, file_buffer, stat.mode);

            count = count + 1;

            direct_log("\rinfo: 🔍 Files Packed: {}", .{count});
        }
    }
    direct_log("\n", .{});

    // Log success
    log.info("Archived {} files into payload! 📥", .{count});

    // Clean up memory
    walker.deinit();

    // Close the archive file
    try write_magic_number(&foilz_writer);

    arch_file.close();
}

pub fn write_magic_number(foilz_writer: *const fs.File.Writer) !void {
    _ = try foilz_writer.write(MAGIC);
}

pub fn write_file_record(foilz_writer: *const fs.File.Writer, name: []const u8, data: []const u8, mode: u64) !void {
    _ = try foilz_writer.writeInt(u64, name.len, .Little);
    _ = try foilz_writer.write(name);
    _ = try foilz_writer.writeInt(u64, data.len, .Little);
    _ = try foilz_writer.write(data);
    _ = try foilz_writer.writeInt(u64, mode, .Little);
}

pub fn validate_magic(first_bytes: []const u8) bool {
    return mem.eql(u8, first_bytes, MAGIC);
}

pub fn unpack_files(data: []const u8, dest_path: []const u8, uncompressed_size: u64) !void {
    // Decompress the data in the payload

    var decompress_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer decompress_arena.deinit();
    var allocator = decompress_arena.allocator();

    var decompressed: []u8 = try allocator.alloc(u8, uncompressed_size);

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
    if (!validate_magic(decompressed[0..5])) {
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
        var string_len = std.mem.readIntSliceLittle(u64, decompressed[cursor .. cursor + @sizeOf(u64)]);
        cursor = cursor + @sizeOf(u64);

        var file_name = decompressed[cursor .. cursor + string_len];
        cursor = cursor + string_len;

        //////
        // Read the file data from the payload
        var file_len = std.mem.readIntSliceLittle(u64, decompressed[cursor .. cursor + @sizeOf(u64)]);
        cursor = cursor + @sizeOf(u64);

        var file_data = decompressed[cursor .. cursor + file_len];
        cursor = cursor + file_len;

        //////
        // Read the mode for this file
        var file_mode = std.mem.readIntSliceLittle(u64, decompressed[cursor .. cursor + @sizeOf(u64)]);
        cursor = cursor + @sizeOf(u64);

        //////
        // Write the file
        const full_file_path = try fs.path.join(allocator, &[_][]const u8{ dest_path[0..], file_name });

        //////
        // Create any directories needed
        const dir_name = fs.path.dirname(file_name);
        try create_dirs(dest_path[0..], dir_name.?, allocator);

        log.debug("Unpacked File: {s}", .{full_file_path});

        //////
        // Write the file to disk!

        // If we're on windows don't try and use file_mode because NTFS doesn't have that!
        if (builtin.os.tag == .windows) {
            const file = try fs.createFileAbsolute(full_file_path, .{ .truncate = true });
            try file.writeAll(file_data);
            file.close();
        } else {
            const file = try fs.createFileAbsolute(full_file_path, .{ .truncate = true, .mode = @intCast(os.mode_t, file_mode) });
            try file.writeAll(file_data);
            file.close();
        }

        file_count = file_count + 1;
    }

    log.debug("Unpacked {} files", .{file_count});
}

fn create_dirs(dest_path: []const u8, sub_dir_names: []const u8, allocator: std.mem.Allocator) !void {
    var iterator = mem.split(u8, sub_dir_names, "/");
    var full_dir_path = try fs.path.join(allocator, &[_][]const u8{ dest_path, "" });

    while (iterator.next()) |sub_dir| {
        full_dir_path = try fs.path.join(allocator, &[_][]const u8{ full_dir_path, sub_dir });
        os.mkdir(full_dir_path, 0o755) catch {};
    }
}

// Adapted from `std.log`, but without forcing a newline
fn direct_log(comptime message: []const u8, args: anytype) void {
    const stderrLock = std.debug.getStderrMutex();
    stderrLock.lock();
    defer stderrLock.unlock();
    const stderr = std.io.getStdErr().writer(); // Using the same IO as `std.log`
    nosuspend stderr.print(message, args) catch return;
}
