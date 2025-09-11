const std = @import("std");
const fs = std.fs;
const util = @import("util");
const getopt = util.getopt;

pub fn main() !void {
    var opts = getopt.init("a:b::c");
    while (try opts.next()) |opt| switch (opt) {
        'a' => try stdout.print(
            "Option 'a' with argument: {s}\n",
            .{opts.optarg.?},
        ),
        'b' => if (opts.optarg) |arg|
            try stdout.print("Option 'b' with argument: {s}\n", .{arg})
        else
            try stdout.print("Option 'b' without argument\n", .{}),
        'c' => try stdout.print("Option 'c'\n", .{}),
        else => unreachable,
    };

    if (opts.optind < std.os.argv.len) {
        try stdout.print("Remaining arguments: ", .{});
        for (std.os.argv[opts.optind..]) |arg|
            try stdout.print("  {s} ", .{arg});
        try stdout.print("\n", .{});
    }

    try stdout.flush();
}

var stdout_buffer: [4096]u8 = undefined;
var stdout_writer = fs.File.stdout().writer(&stdout_buffer);
pub const stdout = &stdout_writer.interface;

var stderr_buffer: [4096]u8 = undefined;
var stderr_writer = fs.File.stderr().writer(&stderr_buffer);
pub const stderr = &stderr_writer.interface;

var stdin_buffer: [4096]u8 = undefined;
var stdin_reader = fs.File.stdin().reader(&stdin_buffer);
pub const stdin = &stdin_reader.interface;
