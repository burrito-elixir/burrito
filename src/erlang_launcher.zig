const std = @import("std");

const builtin = @import("builtin");
const fs = std.fs;
const log = std.log;
const metadata = @import("metadata.zig");
const win_asni = @cImport(@cInclude("win_ansi_fix.h"));

const MetaStruct = metadata.MetaStruct;
const BufMap = std.BufMap;

const MAX_READ_SIZE = 1000000000;

pub fn launch(install_dir: []const u8, env_map: *BufMap, meta: *const MetaStruct, args_trimmed: []const []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();

    // Computer directories we care about
    const release_cookie_path = try fs.path.join(allocator, &[_][]const u8{ install_dir, "releases", "COOKIE" });
    const release_lib_path = try fs.path.join(allocator, &[_][]const u8{ install_dir, "lib" });
    const install_vm_args_path = try fs.path.join(allocator, &[_][]const u8{ install_dir, "releases", meta.app_version, "vm.args" });
    const rel_vsn_dir = try fs.path.join(allocator, &[_][]const u8{ install_dir, "releases", meta.app_version });
    const boot_path = try fs.path.join(allocator, &[_][]const u8{ rel_vsn_dir, "start" });

    // Construct the ERTS 'erl' executable full path
    const erts_version_name = try std.fmt.allocPrint(allocator, "erts-{s}", .{ meta.erts_version });
    const erl_bin_path = try fs.path.join(allocator, &[_][]const u8{ install_dir, erts_version_name, "bin", "erl" });

    // Read the Erlang COOKIE file for the release
    const release_cookie_file = try fs.openFileAbsolute(release_cookie_path, .{ .read = true, .write = false });
    const release_cookie_content = try release_cookie_file.readToEndAlloc(allocator, MAX_READ_SIZE);

    // Set all the require relese environment variables

    try env_map.put("NODE_NAME", meta.app_name[0..]);

    const erlang_cli = &[_][]const u8{
        erl_bin_path[0..], 
        "-elixir ansi_enabled true", 
        "-noshell", 
        "-s elixir start_cli", 
        "-mode embedded", 
        "-setcookie",
        release_cookie_content,
        "-boot",
        boot_path,
        "-boot_var",
        "RELEASE_LIB",
        release_lib_path,
        "-args_file",
        install_vm_args_path,
        "-extra",
    };

    if (builtin.os.tag == .windows) {
        // Fix up Windows 10+ consoles having ANSI escape support, but only if we set some flags
        win_asni.enable_virtual_term();

        // HACK: To get aroung the many issues with escape characters (like ", ', =, !, and %) in Windows
        // we will encode each argument as a base64 string, these will be then be decoded using `Burrito.Util.Args.get_arguments/0`.
        try env_map.put("_ARGUMENTS_ENCODED", "1");
        var encoded_list = std.ArrayList([]u8).init(allocator);
        defer encoded_list.deinit();

        for (args_trimmed) |argument| {
            const encoded_len = std.base64.standard_no_pad.Encoder.calcSize(argument.len);
            const argument_encoded = try allocator.alloc(u8, encoded_len);
            _ = std.base64.standard_no_pad.Encoder.encode(argument_encoded, argument);
            try encoded_list.append(argument_encoded);
        }

        const encoded_args_string = try std.mem.join(allocator, " ", encoded_list);
        const final_args = try std.mem.concat(allocator, []const u8, &.{ erlang_cli,  &[_][]const u8{encoded_args_string} });

        const win_child_proc = try std.ChildProcess.init(final_args, allocator);
        win_child_proc.env_map = &env_map;
        win_child_proc.stdout_behavior = .Inherit;
        win_child_proc.stdin_behavior = .Inherit;

        log.debug("CLI List: {s}", .{final_args});

        const win_term = try win_child_proc.spawnAndWait();
        switch (win_term) {
            .Exited => |code| {
                std.process.exit(code);
            },
            else => std.process.exit(1),
        }
    } else {
        const args_string = try std.mem.join(allocator, " ", args_trimmed);
        const final_args = try std.mem.concat(allocator, []const u8, &.{ erlang_cli,  &[_][]const u8{args_string} });

        log.debug("CLI List: {s}", .{final_args});

        return std.process.execve(allocator, final_args, env_map);
    }
}