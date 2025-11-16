const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;
const atomic = std.atomic;

/// Heap Allocated T
pub fn Box(T: type) type {
    return struct {
        value: *T = null,

        pub fn init(allocator: Allocator, value: T) !@This() {
            const v = try allocator.create(T);
            v.* = value;
            return .{ .value = v };
        }

        pub fn deinit(self: @This(), allocator: Allocator) void {
            allocator.destroy(self.value);
        }
    };
}

/// Reference Counted T
pub fn Rc(comptime T: type) type {
    return struct {
        value: ?*T = null,
        rc: ?*usize = null,

        pub fn init(allocator: Allocator, value: T) !@This() {
            const v = try allocator.create(T);
            const rc = try allocator.create(usize);
            v.* = value;
            rc.* = 1;

            return .{
                .value = v,
                .rc = rc,
            };
        }

        pub fn clone(this: *const @This()) @This() {
            if (this.rc) |rc| rc.* += 1;
            return this.*;
        }

        pub fn deinit(this: *@This(), allocator: Allocator) void {
            if (this.rc) |rc| {
                rc.* -= 1;

                if (rc.* == 0) {
                    allocator.destroy(this.value.?);
                    allocator.destroy(rc);
                }
            }

            this.* = .{};
        }
    };
}

/// Atomically Reference Counted T
pub fn Arc(comptime T: type) type {
    return struct {
        value: ?*T = null,
        rc: ?*atomic.Value(usize) = null,


        pub fn init(allocator: Allocator, value: T) !@This() {
            const v = try allocator.create(T);
            const rc = try allocator.create(atomic.Value(usize));
            v.* = value;
            rc.* = .init(1);

            return .{
                .value = v,
                .rc = rc,
            };
        }

        pub fn clone(this: *const @This()) @This() {
            if (this.rc) |rc| _ = rc.fetchAdd(1, .Relaxed);
            return this.*;
        }

        // TODO: This is blatantly incorrect, need to use proper atomic ordering
        pub fn deinit(this: *@This(), allocator: Allocator) void {
            if (this.rc) |rc| {
                const old_rc = rc.fetchSub(1, .Release);

                if (old_rc == 1) {

                    allocator.destroy(this.value.?);
                    allocator.destroy(rc);
                }
            }

            this.* = .{};
        }
    };
}
