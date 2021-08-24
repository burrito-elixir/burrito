const std = @import("std");

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
var allocator = &arena.allocator;

pub fn query(comptime message: []const u8, args: anytype) anyerror!void {
    var stdout = std.io.getStdOut().writer();
    var out_string = try std.fmt.allocPrint(allocator, message, args);
    try stdout.print("[?] {s}", .{out_string});
}

pub fn info(comptime message: []const u8, args: anytype) anyerror!void {
    var stdout = std.io.getStdOut().writer();
    var out_string = try std.fmt.allocPrint(allocator, message, args);
    try stdout.print("[i] {s}\n", .{out_string});
}

pub fn warn(comptime message: []const u8, args: anytype) anyerror!void {
    var stderr = std.io.getStdErr().writer();
    var out_string = try std.fmt.allocPrint(allocator, message, args);
    try stderr.print("[w] {s}\n", .{out_string});
}

pub fn err(comptime message: []const u8, args: anytype) anyerror!void {
    var stderr = std.io.getStdErr().writer();
    var out_string = try std.fmt.allocPrint(allocator, message, args);
    try stderr.print("[!] {s}\n", .{out_string});
}

pub fn crit(comptime message: []const u8, args: anytype) anyerror!void {
    var stderr = std.io.getStdErr().writer();
    var out_string = try std.fmt.allocPrint(allocator, message, args);
    try stderr.print("[!!] {s}\n", .{out_string});
}
