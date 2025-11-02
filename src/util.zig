const std = @import("std");
const testing = std.testing;

pub const getopt = @import("util/getopt.zig");
pub const err = @import("util/err.zig").err;
pub const syscall = @import("util/err.zig").syscall;
pub const term = @import("util/term.zig");

test {
    testing.refAllDeclsRecursive(@This());
}
