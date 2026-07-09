const std = @import("std");
const builtin = @import("builtin");

const logger = @import("logger.zig");
const metadata = @import("metadata.zig");
const install = @import("install.zig");
const wrapper = @import("wrapper.zig");

const MetaStruct = metadata.MetaStruct;

// Directory (inside an install dir) holding one pidfile per process currently
// executing from that install. Written by the launcher before it execs the
// runtime; consulted by do_clean_old_versions so a newer version's cleanup
// never deletes a payload out from under a still-running older process.
pub const live_dir_name = ".burrito_live";

pub fn do_maint(args: [][:0]u8, install_dir: []const u8) !void {
    var stdout_buf: [64]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;

    if (args.len < 1) {
        logger.warn("No sub-command provided!", .{});
    } else {
        if (std.mem.eql(u8, args[0], "uninstall")) {
            try do_uninstall(install_dir);
        }

        if (std.mem.eql(u8, args[0], "directory")) {
            try print_install_dir(stdout, install_dir);
        }

        if (std.mem.eql(u8, args[0], "meta")) {
            try print_metadata(stdout);
        }
    }
}

fn confirm() !bool {
    var stdin_buf: [8]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buf);
    var stdin = &stdin_reader.interface;

    logger.query("Please confirm this action [y/n]: ", .{});

    if (stdin.takeDelimiterExclusive('\n')) |user_input| {
        if (std.mem.eql(u8, user_input[0..1], "y") or std.mem.eql(u8, user_input[0..1], "Y")) {
            return true;
        }
    } else |err| {
        logger.err("Failed to confirm: {t}", .{err});
        return err;
    }

    return false;
}

fn do_uninstall(install_dir: []const u8) !void {
    logger.warn("This will uninstall the application runtime for this Burrito binary!", .{});
    if (try confirm() == false) {
        logger.warn("Uninstall was aborted!", .{});
        logger.info("Quitting.", .{});
        return;
    }

    logger.info("Deleting directory: {s}", .{install_dir});
    try std.fs.deleteTreeAbsolute(install_dir);
    logger.info("Uninstall complete!", .{});
    logger.info("Quitting.", .{});
}

fn print_metadata(out: *std.Io.Writer) !void {
    try out.print("{s}", .{wrapper.RELEASE_METADATA_JSON});
    try out.flush();
}

fn print_install_dir(out: *std.Io.Writer, install_dir: []const u8) !void {
    try out.print("{s}\n", .{install_dir});
    try out.flush();
}

pub fn do_clean_old_versions(install_prefix_path: []const u8, current_install_path: []const u8) !void {
    std.log.debug("Going to clean up older versions of this application...", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Escape hatch: skip cleanup entirely when requested via the environment.
    if (std.process.getEnvVarOwned(allocator, "BURRITO_NO_CLEAN_OLD")) |_| {
        std.log.debug("BURRITO_NO_CLEAN_OLD is set, skipping cleanup of older versions", .{});
        return;
    } else |_| {}

    const prefix_dir = try std.fs.openDirAbsolute(install_prefix_path, .{ .access_sub_paths = true, .iterate = true });

    const current_install = try install.load_install_from_path(allocator, current_install_path);

    var itr = prefix_dir.iterate();
    while (try itr.next()) |dir| {
        if (dir.kind == .directory) {
            const possible_app_path = try std.fs.path.join(allocator, &[_][]const u8{ install_prefix_path, dir.name });
            const other_install = try install.load_install_from_path(allocator, possible_app_path);

            // If can can't figure out if this is an install dir, just ignore it
            if (other_install == null) {
                continue;
            }

            // If this isn't the same installed app as us ignore it
            if (!std.mem.eql(u8, current_install.?.metadata.app_name, other_install.?.metadata.app_name)) {
                continue;
            }

            // Compare the version, if it's older, delete the directory
            if (std.SemanticVersion.order(current_install.?.version, other_install.?.version) == .gt) {
                // Never delete an install a live process is still executing from:
                // deleting it makes that process crash later with a `nofile`
                // module-load kernel panic the first time it lazily loads a module.
                if (install_in_use(allocator, other_install.?.install_dir_path)) {
                    logger.log_stderr("Skipped cleanup of older version (v{s}): still in use by a running process", .{other_install.?.metadata.app_version});
                    continue;
                }
                try std.fs.deleteTreeAbsolute(other_install.?.install_dir_path);
                logger.log_stderr("Uninstalled older version (v{s})", .{other_install.?.metadata.app_version});
            }
        }
    }
}

// Record the current process in <install_dir>/.burrito_live/<pid> before the
// launcher execs the runtime. The exec preserves our PID, so the pidfile stays
// accurate for the app's whole lifetime; stale pidfiles (dead PIDs) are pruned
// opportunistically. Best-effort: failures must never block a launch.
pub fn mark_install_live(allocator: std.mem.Allocator, install_dir: []const u8) void {
    if (builtin.os.tag == .windows) return;

    const live_path = std.fs.path.join(allocator, &[_][]const u8{ install_dir, live_dir_name }) catch return;
    defer allocator.free(live_path);
    std.fs.cwd().makePath(live_path) catch return;

    // Prune dead siblings while we're here so the dir can't grow unboundedly.
    _ = install_in_use(allocator, install_dir);

    const pid_name = std.fmt.allocPrint(allocator, "{d}", .{current_pid()}) catch return;
    defer allocator.free(pid_name);
    const pid_path = std.fs.path.join(allocator, &[_][]const u8{ live_path, pid_name }) catch return;
    defer allocator.free(pid_path);
    const pid_file = std.fs.createFileAbsolute(pid_path, .{}) catch return;
    pid_file.close();
}

// True if any PID recorded under <install_path>/.burrito_live is still alive.
// Prunes pidfiles whose process is gone as a side effect. On Windows there is
// no cheap liveness probe, so this reports not-in-use (the upstream behavior);
// in-use executables there are protected by mandatory file locking anyway.
fn install_in_use(allocator: std.mem.Allocator, install_path: []const u8) bool {
    if (builtin.os.tag == .windows) return false;

    const live_path = std.fs.path.join(allocator, &[_][]const u8{ install_path, live_dir_name }) catch return false;
    defer allocator.free(live_path);
    var live_dir = std.fs.openDirAbsolute(live_path, .{ .access_sub_paths = true, .iterate = true }) catch return false;
    defer live_dir.close();

    var in_use = false;
    var itr = live_dir.iterate();
    while (itr.next() catch return in_use) |entry| {
        if (entry.kind != .file) continue;
        const pid = std.fmt.parseInt(std.posix.pid_t, entry.name, 10) catch continue;
        if (pid_is_alive(pid)) {
            in_use = true;
        } else {
            live_dir.deleteFile(entry.name) catch {};
        }
    }
    return in_use;
}

fn pid_is_alive(pid: std.posix.pid_t) bool {
    std.posix.kill(pid, 0) catch |err| {
        // PermissionDenied (EPERM) means the process exists but belongs to
        // someone else -- that still counts as alive. Anything else (ESRCH)
        // means it is gone.
        return err == error.PermissionDenied;
    };
    return true;
}

fn current_pid() std.posix.pid_t {
    if (builtin.os.tag == .linux) {
        return @intCast(std.os.linux.getpid());
    }
    return @intCast(std.c.getpid());
}

test "pid_is_alive: our own pid is alive" {
    try std.testing.expect(pid_is_alive(current_pid()));
}

test "pid_is_alive: pid 1 (init/launchd) counts as alive via EPERM" {
    try std.testing.expect(pid_is_alive(1));
}

test "install_in_use: live pidfile blocks cleanup, stale pidfile is pruned" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const allocator = std.testing.allocator;

    const install_path = try tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(install_path);

    // No .burrito_live dir at all -> not in use.
    try std.testing.expect(!install_in_use(allocator, install_path));

    try tmp.dir.makePath(live_dir_name);

    // A pidfile for our own (alive) process -> in use.
    const our_pid_name = try std.fmt.allocPrint(allocator, "{s}/{d}", .{ live_dir_name, current_pid() });
    defer allocator.free(our_pid_name);
    (try tmp.dir.createFile(our_pid_name, .{})).close();
    try std.testing.expect(install_in_use(allocator, install_path));
    try tmp.dir.deleteFile(our_pid_name);

    // A pidfile for a process that has exited -> not in use, and pruned.
    var child = std.process.Child.init(&[_][]const u8{"/usr/bin/true"}, allocator);
    try child.spawn();
    const dead_pid = child.id;
    _ = try child.wait();

    const dead_pid_name = try std.fmt.allocPrint(allocator, "{s}/{d}", .{ live_dir_name, dead_pid });
    defer allocator.free(dead_pid_name);
    (try tmp.dir.createFile(dead_pid_name, .{})).close();
    try std.testing.expect(!install_in_use(allocator, install_path));
    // Stale pidfile was pruned as a side effect.
    try std.testing.expectError(error.FileNotFound, tmp.dir.access(dead_pid_name, .{}));

    // Garbage pidfile names are ignored.
    const junk_name = try std.fmt.allocPrint(allocator, "{s}/not-a-pid", .{live_dir_name});
    defer allocator.free(junk_name);
    (try tmp.dir.createFile(junk_name, .{})).close();
    try std.testing.expect(!install_in_use(allocator, install_path));
}
