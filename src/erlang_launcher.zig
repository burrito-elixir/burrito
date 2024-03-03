const std = @import("std");

const builtin = @import("builtin");
const fs = std.fs;
const log = std.log;
const metadata = @import("metadata.zig");
const win_asni = @cImport(@cInclude("win_ansi_fix.h"));

const MetaStruct = metadata.MetaStruct;
const EnvMap = std.process.EnvMap;

const MAX_READ_SIZE = 256;

fn get_erl_exe_name() []const u8 {
    if (builtin.os.tag == .windows) {
        return "erl.exe";
    } else {
        return "erlexec";
    }
}

pub fn launch(install_dir: []const u8, env_map: *EnvMap, meta: *const MetaStruct, args_trimmed: []const []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();

    // Computer directories we care about
    const release_cookie_path = try fs.path.join(allocator, &[_][]const u8{ install_dir, "releases", "COOKIE" });
    const release_lib_path = try fs.path.join(allocator, &[_][]const u8{ install_dir, "lib" });
    const install_vm_args_path = try fs.path.join(allocator, &[_][]const u8{ install_dir, "releases", meta.app_version, "vm.args" });
    const config_sys_path = try fs.path.join(allocator, &[_][]const u8{ install_dir, "releases", meta.app_version, "sys.config" });
    const config_sys_path_no_ext = try fs.path.join(allocator, &[_][]const u8{ install_dir, "releases", meta.app_version, "sys" });
    const rel_vsn_dir = try fs.path.join(allocator, &[_][]const u8{ install_dir, "releases", meta.app_version });
    const boot_path = try fs.path.join(allocator, &[_][]const u8{ rel_vsn_dir, "start" });

    const erts_version_name = try std.fmt.allocPrint(allocator, "erts-{s}", .{meta.erts_version});
    const erts_bin_path = try fs.path.join(allocator, &[_][]const u8{ install_dir, erts_version_name, "bin" });
    const erl_bin_path = try fs.path.join(allocator, &[_][]const u8{ erts_bin_path, get_erl_exe_name() });

    // Read the Erlang COOKIE file for the release
    const release_cookie_file = try fs.openFileAbsolute(release_cookie_path, .{ .mode = .read_write });
    const release_cookie_content = try release_cookie_file.readToEndAlloc(allocator, MAX_READ_SIZE);

    // Set all the required release arguments

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
        "-config",
        config_sys_path,
        "-extra",
    };

    if (builtin.os.tag == .windows) {
        // Fix up Windows 10+ consoles having ANSI escape support, but only if we set some flags
        win_asni.enable_virtual_term();
        const final_args = try std.mem.concat(allocator, []const u8, &.{ erlang_cli, args_trimmed });

        try env_map.put("RELEASE_ROOT", install_dir);
        try env_map.put("RELEASE_SYS_CONFIG", config_sys_path_no_ext);
        try env_map.put("__BURRITO", "1");

        var win_child_proc = std.ChildProcess.init(final_args, allocator);
        win_child_proc.env_map = env_map;
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
        const final_args = try std.mem.concat(allocator, []const u8, &.{ erlang_cli, args_trimmed });

        log.debug("CLI List: {s}", .{final_args});

        var erl_env_map = EnvMap.init(allocator);
        defer erl_env_map.deinit();

        var env_map_it = env_map.iterator();
        while (env_map_it.next()) |entry| {
            const key = entry.key_ptr.*;
            const val = entry.value_ptr.*;
            try erl_env_map.put(key, val);
        }

        try erl_env_map.put("ROOTDIR", install_dir[0..]);
        try erl_env_map.put("BINDIR", erts_bin_path[0..]);
        try erl_env_map.put("RELEASE_ROOT", install_dir);
        try erl_env_map.put("RELEASE_SYS_CONFIG", config_sys_path_no_ext);
        try erl_env_map.put("__BURRITO", "1");

        return std.process.execve(allocator, final_args, &erl_env_map);
    }
}
