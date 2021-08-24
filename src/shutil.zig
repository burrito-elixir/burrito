const std = @import("std");
const builtin = @import("builtin");

pub fn is_tty() bool {
    var stdout = std.io.getStdOut();
    return stdout.isTty();
}
