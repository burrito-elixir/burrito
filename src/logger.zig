const std = @import("std");

var log = std.log;
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
var allocator = arena.allocator();

pub fn query(comptime message: []const u8, args: anytype) void {
    var stdout = std.io.getStdOut().writer();
    var out_string = std.fmt.allocPrint(allocator, message, args);
    stdout.print("[?] {s}", .{out_string}) catch {};
}

pub fn info(comptime message: []const u8, args: anytype) void {
    var stdout = std.io.getStdOut().writer();
    var out_string = std.fmt.allocPrint(allocator, message, args);
    stdout.print("[i] {s}\n", .{out_string}) catch {};
}

pub fn warn(comptime message: []const u8, args: anytype) void {
    var stderr = std.io.getStdErr().writer();
    var out_string = std.fmt.allocPrint(allocator, message, args);
    stderr.print("[w] {s}\n", .{out_string}) catch {};
}

pub fn err(comptime message: []const u8, args: anytype) void {
    var stderr = std.io.getStdErr().writer();
    var out_string = std.fmt.allocPrint(allocator, message, args);
    stderr.print("[!] {s}\n", .{out_string}) catch {};
}

pub fn crit(comptime message: []const u8, args: anytype) void {
    var stderr = std.io.getStdErr().writer();
    var out_string = std.fmt.allocPrint(allocator, message, args);
    stderr.print("[!!] {s}\n", .{out_string}) catch {};
}
