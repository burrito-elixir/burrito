const std = @import("std");

const builtin = @import("builtin");
const Io = std.Io;
const log = std.log;
const metadata = @import("metadata.zig");

const MetaStruct = metadata.MetaStruct;

const MAX_READ_SIZE = 256;

fn get_erl_exe_name() []const u8 {
    if (builtin.os.tag == .windows) {
        return "erl.exe";
    } else {
        return "erlexec";
    }
}

pub fn launch(io: Io, install_dir: []const u8, env_map: *std.process.Environ.Map, meta: *const MetaStruct, self_path: []const u8, args_trimmed: []const []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    // Computer directories we care about
    const release_cookie_path = try std.fs.path.join(allocator, &[_][]const u8{ install_dir, "releases", "COOKIE" });
    const release_lib_path = try std.fs.path.join(allocator, &[_][]const u8{ install_dir, "lib" });
    const install_vm_args_path = try std.fs.path.join(allocator, &[_][]const u8{ install_dir, "releases", meta.app_version, "vm.args" });
    const config_sys_path = try std.fs.path.join(allocator, &[_][]const u8{ install_dir, "releases", meta.app_version, "sys.config" });
    const config_sys_path_no_ext = try std.fs.path.join(allocator, &[_][]const u8{ install_dir, "releases", meta.app_version, "sys" });
    const rel_vsn_dir = try std.fs.path.join(allocator, &[_][]const u8{ install_dir, "releases", meta.app_version });
    const boot_path = try std.fs.path.join(allocator, &[_][]const u8{ rel_vsn_dir, "start" });

    const erts_version_name = try std.fmt.allocPrint(allocator, "erts-{s}", .{meta.erts_version});
    const erts_bin_path = try std.fs.path.join(allocator, &[_][]const u8{ install_dir, erts_version_name, "bin" });
    const erl_bin_path = try std.fs.path.join(allocator, &[_][]const u8{ erts_bin_path, get_erl_exe_name() });

    // Read the Erlang COOKIE file for the release
    const release_cookie_file = try Io.Dir.openFileAbsolute(io, release_cookie_path, .{ .mode = .read_write });
    defer release_cookie_file.close(io);
    var read_buf: [1024]u8 = undefined;
    var cookie_reader = release_cookie_file.reader(io, &read_buf);
    var release_cookie_content: []const u8 = try cookie_reader.interface.allocRemaining(allocator, @enumFromInt(MAX_READ_SIZE));

    // Override the cookie if the env variable RELEASE_COOKIE is defined
    if (env_map.get("RELEASE_COOKIE")) |cookie| {
        release_cookie_content = cookie;
    }

    // Set all the required release arguments. CLI args are passed
    // through native argv (after `-extra` below) and reach the BEAM
    // via :init.get_plain_arguments/0.

    const erlang_cli = &[_][]const u8{
        erl_bin_path[0..],
        "-elixir",
        "ansi_enabled",
        "true",
        "-noshell",
        "-s",
        "elixir",
        "start_cli",
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

    // Cross-platform: build args once, set env, spawn child, wait for exit
    const final_args = try std.mem.concat(allocator, []const u8, &.{ erlang_cli, args_trimmed });

    log.debug("CLI List: {any}", .{final_args});

    try env_map.put("RELEASE_ROOT", install_dir);
    try env_map.put("RELEASE_SYS_CONFIG", config_sys_path_no_ext);
    try env_map.put("__BURRITO", "1");
    try env_map.put("__BURRITO_BIN_PATH", self_path);

    // Unix: set ROOTDIR, BINDIR, LD_LIBRARY_PATH for NIF .so files
    if (builtin.os.tag != .windows) {
        try env_map.put("ROOTDIR", install_dir[0..]);
        try env_map.put("BINDIR", erts_bin_path[0..]);

        // Extend LD_LIBRARY_PATH so NIF .so files can find system shared
        // libraries (e.g. libgcc_s.so.1) when using a custom ERTS
        const system_lib_paths = "/lib/x86_64-linux-gnu:/usr/lib/x86_64-linux-gnu:/lib:/usr/lib";
        if (env_map.get("LD_LIBRARY_PATH")) |existing| {
            const combined = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ existing, system_lib_paths });
            try env_map.put("LD_LIBRARY_PATH", combined);
        } else {
            try env_map.put("LD_LIBRARY_PATH", system_lib_paths);
        }
    }

    // On Unix: pipe child stdout through us so we can detect EPIPE from
    // the downstream consumer (e.g. `app cmd | head -5`). When the consumer
    // exits and breaks the pipe, the copy thread kills the BEAM child.
    // On Windows: inherit stdout directly — std.c.read blocks on Windows
    // pipes, and the EPIPE group-leader hang is Unix-specific anyway.
    var child: std.process.Child = undefined;
    var copy_thread: ?std.Thread = null;

    if (builtin.os.tag != .windows) {
        child = try std.process.spawn(io, .{
            .argv = final_args,
            .environ_map = env_map,
            .stdout = .pipe,
        });
        copy_thread = try std.Thread.spawn(.{}, stdoutCopyThread, .{io, &child});
    } else {
        child = try std.process.spawn(io, .{
            .argv = final_args,
            .environ_map = env_map,
        });
    }

    const term = if (builtin.os.tag != .windows)
        child.wait(io) catch {
            copy_thread.?.join();
            std.process.exit(0);
        }
    else
        try child.wait(io);

    if (copy_thread) |t| t.join();

    switch (term) {
        .exited => |code| std.process.exit(code),
        else => std.process.exit(1),
    }
}

/// Copies child process stdout to our stdout (Unix only).
/// When the downstream pipe breaks (EPIPE), kills the child to prevent
/// it from hanging during VM shutdown (BEAM tries to flush standard_io
/// which blocks forever on a dead pipe).
fn stdoutCopyThread(io: Io, child: *std.process.Child) void {
    if (builtin.os.tag == .windows) return;
    const stdout_file = child.stdout orelse return;
    const stdin_fd = stdout_file.handle;
    const stdout_fd = Io.File.stdout().handle;
    var buf: [16384]u8 = undefined;

    while (true) {
        const n = std.posix.read(stdin_fd, &buf) catch break;
        if (n == 0) break;
        const written = std.c.write(stdout_fd, buf[0..n].ptr, n);
        if (written < 0) {
            child.kill(io);
            return;
        }
    }
}
