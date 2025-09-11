const std = @import("std");
const linux = std.os.linux;
const assert = std.debug.assert;
const builtin = @import("builtin");

pub inline fn syscall(comptime @"fn": anytype, args: anytype) !usize {
    assert(@typeInfo(@TypeOf(@"fn")) == builtin.Type.@"fn");
    assert(@typeInfo(@TypeOf(args)) == builtin.Type.@"struct" and @typeInfo(@TypeOf(args)).@"struct".is_tuple);

    const log = std.log.scoped(.syscall);

    const result: usize = @intCast(@call(.auto, @"fn", args));
    return ret: switch (linux.E.init(result)) {
        .SUCCESS => {
            log.debug("{s} ({any}) -> {d}", .{ @typeName(@TypeOf(@"fn")), args, result });
            break :ret result;
        },
        else => |errno| {
            log.err("{s} ({any}) -> {any}", .{ @typeName(@TypeOf(@"fn")), args, errno });
            break :ret error.SyscallFailed;
        },
    };
}

pub inline fn err(res: usize) !usize {
    const log = std.log.scoped(.syscall);
    const ec = linux.E.init(res);
    if (ec != linux.E.SUCCESS) {
        log.err("syscall failed: {any}({d})", .{ ec, res });
        return error.SyscallFailed;
    }
    return res;
}
