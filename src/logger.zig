const std = @import("std");

pub fn query(comptime message: []const u8, args: anytype) void {
    printToStdout("[?] " ++ message, args);
}

pub fn log_stderr(comptime message: []const u8, args: anytype) void {
    printToStderr("[l] " ++ message ++ "\n", args);
}

pub fn info(comptime message: []const u8, args: anytype) void {
    printToStdout("[i] " ++ message ++ "\n", args);
}

pub fn warn(comptime message: []const u8, args: anytype) void {
    printToStderr("[w] " ++ message ++ "\n", args);
}

pub fn err(comptime message: []const u8, args: anytype) void {
    printToStderr("[!] " ++ message ++ "\n", args);
}

pub fn crit(comptime message: []const u8, args: anytype) void {
    printToStderr("[!!] " ++ message ++ "\n", args);
}

fn printToStdout(comptime message: []const u8, args: anytype) void {
    var stdout_buf: [64]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;

    stdout.print(message, args) catch {};
    stdout.flush() catch {};
}

fn printToStderr(comptime message: []const u8, args: anytype) void {
    var stderr_buf: [64]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buf);
    const stderr = &stderr_writer.interface;

    stderr.print(message, args) catch {};
    stderr.flush() catch {};
}
