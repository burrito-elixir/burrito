const std = @import("std");

pub fn query(comptime message: []const u8, args: anytype) void {
    var stdout = std.io.getStdOut().writer();
    stdout.print("[?] " ++ message, args) catch {};
}

pub fn log_stderr(comptime message: []const u8, args: anytype) void {
    var stderr = std.io.getStdErr().writer();
    stderr.print("[l] " ++ message ++ "\n", args) catch {};
}

pub fn info(comptime message: []const u8, args: anytype) void {
    var stdout = std.io.getStdOut().writer();
    stdout.print("[i] " ++ message ++ "\n", args) catch {};
}

pub fn warn(comptime message: []const u8, args: anytype) void {
    var stderr = std.io.getStdErr().writer();
    stderr.print("[w] " ++ message ++ "\n", args) catch {};
}

pub fn err(comptime message: []const u8, args: anytype) void {
    var stderr = std.io.getStdErr().writer();
    stderr.print("[!] " ++ message ++ "\n", args) catch {};
}

pub fn crit(comptime message: []const u8, args: anytype) void {
    var stderr = std.io.getStdErr().writer();
    stderr.print("[!!] " ++ message ++ "\n", args) catch {};
}
