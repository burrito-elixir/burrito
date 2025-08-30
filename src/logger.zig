const std = @import("std");

var stdout_buf: [64]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
const stdout = &stdout_writer.interface;

var stderr_buf: [64]u8 = undefined;
var stderr_writer = std.fs.File.stderr().writer(&stderr_buf);
const stderr = &stderr_writer.interface;

pub fn query(comptime message: []const u8, args: anytype) void {
    stdout.print("[?] " ++ message, args) catch {};
    stdout.flush() catch {};
}

pub fn log_stderr(comptime message: []const u8, args: anytype) void {
    stderr.print("[l] " ++ message ++ "\n", args) catch {};
    stderr.flush() catch {};
}

pub fn info(comptime message: []const u8, args: anytype) void {
    stdout.print("[i] " ++ message ++ "\n", args) catch {};
    stdout.flush() catch {};
}

pub fn warn(comptime message: []const u8, args: anytype) void {
    stderr.print("[w] " ++ message ++ "\n", args) catch {};
    stderr.flush() catch {};
}

pub fn err(comptime message: []const u8, args: anytype) void {
    stderr.print("[!] " ++ message ++ "\n", args) catch {};
    stderr.flush() catch {};
}

pub fn crit(comptime message: []const u8, args: anytype) void {
    stderr.print("[!!] " ++ message ++ "\n", args) catch {};
    stderr.flush() catch {};
}
