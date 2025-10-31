const std = @import("std");
const fs = std.fs;
const ascii = std.ascii;
const sort = std.sort;
const mem = std.mem;
const assert = std.debug.assert;
const os = std.os;
const process = std.process;

pub const Error = error{ InvalidOption, MissingParameter };

const State = enum {
    LookingForOptions,
    ParsingOptionCluster,
    ParsingOptionWithParameter,
    ParsingOptionWithOptionalParameter,
    End,
};

optstring: []const u8,
usagestring: []const u8,
index: usize = 1, // Current index in os.argv
position: usize = 0, // Current position in os.argv[index]
state: State = .LookingForOptions,

optarg: ?[]const u8 = null,
optopt: ?u8 = null,
optind: usize = 0,

pub fn init(comptime optstring: []const u8) @This() {
    comptime for (optstring) |c|
        if (!ascii.isAlphabetic(c) and c != ':')
            @compileError("Invalid character in optstring");

    const usagestring = comptime usage: {
        var flags: []const u8 = ""; // all opts that don't take args
        var options: []const u8 = ""; // all opts that take args
        var optionalOptions: []const u8 = ""; // all opts that take optional args

        for (optstring, 0..) |c, i| if (ascii.isAlphabetic(c)) {
            if (i + 1 < optstring.len and optstring[i + 1] == ':') {
                if (i + 2 < optstring.len and optstring[i + 2] == ':') {
                    optionalOptions = optionalOptions ++ optstring[i .. i + 1];
                } else {
                    options = options ++ optstring[i .. i + 1];
                }
            } else {
                flags = flags ++ optstring[i .. i + 1];
            }
        };

        var usagestring: []const u8 = "";
        if (flags.len > 0) usagestring = usagestring ++ "[-" ++ flags ++ "]";

        for (0..options.len) |i| {
            const prefix = if (usagestring.len == 0) "" else " ";
            usagestring = usagestring ++ prefix ++ "[-" ++ options[i .. i + 1] ++ " <value>]";
        }

        for (0..optionalOptions.len) |i| {
            const prefix = if (usagestring.len == 0) "" else " ";
            usagestring = usagestring ++ prefix ++ "[-" ++ optionalOptions[i .. i + 1] ++ " ?<value>]";
        }

        break :usage usagestring;
    };

    return .{
        .optstring = optstring,
        .optind = partitionArgvInPlace(optstring),
        .usagestring = usagestring,
    };
}

pub fn next(this: *@This()) Error!?u8 {
    this.optarg = null;
    this.optopt = null;

    return value: switch (this.state) {
        .LookingForOptions => {
            if (this.index >= os.argv.len) return null;

            const current: []const u8 = mem.sliceTo(os.argv[this.index], 0);
            const opt = current[this.position];

            if (opt != '-' or ((this.position + 1 < current.len) and
                current[this.position] == '-' and
                current[this.position + 1] == '-'))
            {
                this.state = .End;
                continue :value this.state;
            }

            this.state = .ParsingOptionCluster;
            continue :value this.state;
        },
        .ParsingOptionCluster => {
            this.position += 1;

            const current = mem.sliceTo(os.argv[this.index], 0);

            if (this.position >= current.len) {
                this.index += 1;
                this.position = 0;
                this.state = .LookingForOptions;
                continue :value this.state;
            }

            const opt = current[this.position];
            const index = mem.indexOfScalar(u8, this.optstring, opt);

            if (index == null) {
                this.optopt = opt;
                break :value Error.InvalidOption;
            }

            if (index.? + 2 < this.optstring.len and
                this.optstring[index.? + 1] == ':' and
                this.optstring[index.? + 2] == ':')
            {
                this.state = .ParsingOptionWithOptionalParameter;
                continue :value this.state;
            }

            if (index.? + 1 < this.optstring.len and
                this.optstring[index.? + 1] == ':')
            {
                this.state = .ParsingOptionWithParameter;
                continue :value this.state;
            }

            break :value opt;
        },
        .ParsingOptionWithParameter => {
            this.position += 1;
            const current = mem.sliceTo(os.argv[this.index], 0);
            const opt = current[this.position - 1];

            if (this.position < current.len) {
                if (current[this.position] == '=') this.position += 1;

                this.optarg = current[this.position..];
                this.index += 1;
                this.position = 0;
                this.state = .LookingForOptions;
                break :value opt;
            } else if (this.index + 1 < os.argv.len) {
                this.optarg = mem.sliceTo(os.argv[this.index + 1], 0);
                this.index += 2;
                this.position = 0;
                this.state = .LookingForOptions;
                break :value opt;
            } else {
                this.optopt = opt;
                this.state = .LookingForOptions;
                break :value Error.MissingParameter;
            }
        },
        .ParsingOptionWithOptionalParameter => {
            this.position += 1;
            const current = mem.sliceTo(os.argv[this.index], 0);
            const opt = current[this.position - 1];

            if (this.position < current.len) {
                if (current[this.position] == '=') this.position += 1;
                this.optarg = current[this.position..];
                this.index += 1;
            } else {
                const has_next_arg = (this.index + 1 < os.argv.len);
                const next_arg_is_value = has_next_arg and os.argv[this.index + 1][0] != '-';

                if (next_arg_is_value) {
                    this.optarg = mem.sliceTo(os.argv[this.index + 1], 0);
                    this.index += 2;
                } else {
                    this.optarg = null;
                    this.index += 1;
                }
            }

            this.position = 0;
            this.state = .LookingForOptions;
            break :value opt;
        },
        .End => break :value null,
    };
}

pub fn reset(this: *@This()) void {
    this.index = 1;
    this.position = 0;
    this.optarg = null;
    this.optopt = null;
    this.state = .LookingForOptions;
}

/// Prints the usage to stderr.
pub fn usage(this: *const @This()) !void {
    var stderr_buffer: [4096]u8 = undefined;
    var stderr_writer = fs.File.stderr().writer(&stderr_buffer);
    const stderr = &stderr_writer.interface;

    try stderr.print("usage: {s} {s}\n", .{
        os.argv[0],
        this.usagestring,
    });

    try stderr.flush();
}

pub fn positionals(this: *const @This()) ?@TypeOf(os.argv) {
    return if(this.optind < os.argv.len) os.argv[this.optind..] else null;
}

// https://youtu.be/q9zKYh8sY_E?si=_924uJdHfDiPQ5Dc
fn partitionArgvInPlace(comptime optstring: []const u8) usize {
    var boundary: usize = 1;

    while (true) {
        while (boundary < os.argv.len) {
            const arg = mem.sliceTo(os.argv[boundary], 0);
            const isOption = (arg.len > 0 and arg[0] == '-') and
                !mem.eql(u8, arg, "-") and !mem.eql(u8, arg, "--");

            if (!isOption) break;

            var blockLen: usize = 1;
            if (arg.len > 1) {
                const optChar = arg[1];
                if (mem.indexOfScalar(u8, optstring, optChar)) |optIndex| {
                    if (optIndex + 1 < optstring.len and optstring[optIndex + 1] == ':') {
                        const is_optional = (optIndex + 2 < optstring.len and optstring[optIndex + 2] == ':');
                        const has_next_token = (arg.len == 2 and (boundary + 1 < os.argv.len));

                        if (has_next_token) {
                            if (is_optional) {
                                const next_arg = mem.sliceTo(os.argv[boundary + 1], 0);
                                const next_is_option = (next_arg.len > 0 and next_arg[0] == '-') and
                                    !mem.eql(u8, next_arg, "-") and !mem.eql(u8, next_arg, "--");
                                if (!next_is_option) {
                                    blockLen = 2;
                                }
                            } else {
                                blockLen = 2;
                            }
                        }
                    }
                }
            }
            boundary += blockLen;
        }

        const firstPositional = boundary;

        var nextOption = firstPositional;
        while (nextOption < os.argv.len) : (nextOption += 1) {
            const arg = mem.sliceTo(os.argv[nextOption], 0);
            const isOption = (arg.len > 0 and arg[0] == '-') and
                !mem.eql(u8, arg, "-") and !mem.eql(u8, arg, "--");
            if (isOption) break;
        }

        if (nextOption >= os.argv.len) return firstPositional;

        const optionArg = mem.sliceTo(os.argv[nextOption], 0);
        var optionBlockLen: usize = 1;
        if (optionArg.len > 1) {
            const optChar = optionArg[1];
            if (mem.indexOfScalar(u8, optstring, optChar)) |optIndex| {
                if (optIndex + 1 < optstring.len and optstring[optIndex + 1] == ':') {
                    const is_optional = (optIndex + 2 < optstring.len and optstring[optIndex + 2] == ':');
                    const has_next_token = (optionArg.len == 2 and (nextOption + 1 < os.argv.len));

                    if (has_next_token) {
                        if (is_optional) {
                            const next_arg = mem.sliceTo(os.argv[nextOption + 1], 0);
                            const next_is_option = (next_arg.len > 0 and next_arg[0] == '-') and
                                !mem.eql(u8, next_arg, "-") and !mem.eql(u8, next_arg, "--");
                            if (!next_is_option) {
                                optionBlockLen = 2;
                            }
                        } else {
                            optionBlockLen = 2;
                        }
                    }
                }
            }
        }

        const endOfBlock = nextOption + optionBlockLen;
        const sliceToRotate = os.argv[firstPositional..endOfBlock];
        const mid = nextOption - firstPositional;
        mem.rotate([*:0]u8, sliceToRotate, mid);

        boundary = firstPositional + optionBlockLen;
    }
}

test "getopt empty" {
    const testing = std.testing;
    const allocator = std.testing.allocator;
    const getopt = @This();

    os.argv = argv: {
        var argv: @TypeOf(os.argv) = try allocator.alloc([*:0]u8, 1);
        argv[0] = try allocator.dupeZ(u8, "program");
        break :argv argv;
    };
    defer {
        for (os.argv) |arg| allocator.free(mem.sliceTo(arg, 0));
        allocator.free(os.argv);
    }

    var opts = getopt.init("");

    try testing.expectEqual(null, opts.next());
}

test "getopt empty invalid" {
    const testing = std.testing;
    const allocator = std.testing.allocator;
    const getopt = @This();

    os.argv = argv: {
        var argv: @TypeOf(os.argv) = try allocator.alloc([*:0]u8, 2);
        argv[0] = try allocator.dupeZ(u8, "program");
        argv[1] = try allocator.dupeZ(u8, "-a");
        break :argv argv;
    };
    defer {
        for (os.argv) |arg| allocator.free(mem.sliceTo(arg, 0));
        allocator.free(os.argv);
    }

    var opts = getopt.init("");

    try testing.expectError(Error.InvalidOption, opts.next());
}

test "getopt option cluster" {
    const testing = std.testing;
    const allocator = std.testing.allocator;
    const getopt = @This();

    os.argv = argv: {
        var argv: @TypeOf(os.argv) = try allocator.alloc([*:0]u8, 2);

        argv[0] = try allocator.dupeZ(u8, "program");
        argv[1] = try allocator.dupeZ(u8, "-abc");

        break :argv argv;
    };
    defer {
        for (os.argv) |arg| allocator.free(mem.sliceTo(arg, 0));
        allocator.free(os.argv);
    }

    var opts = getopt.init("abc");

    try testing.expectEqual('a', try opts.next());
    try testing.expectEqual(null, opts.optarg);
    try testing.expectEqual('b', try opts.next());
    try testing.expectEqual(null, opts.optarg);
    try testing.expectEqual('c', try opts.next());
    try testing.expectEqual(null, opts.optarg);
}

test "getopt happy" {
    const testing = std.testing;
    const allocator = std.testing.allocator;
    const getopt = @This();

    os.argv = argv: {
        var argv: @TypeOf(os.argv) = try allocator.alloc([*:0]u8, 5);

        argv[0] = try allocator.dupeZ(u8, "program");
        argv[1] = try allocator.dupeZ(u8, "-a");
        argv[2] = try allocator.dupeZ(u8, "yes");
        argv[3] = try allocator.dupeZ(u8, "-b");
        argv[4] = try allocator.dupeZ(u8, "-c");

        break :argv argv;
    };
    defer {
        for (os.argv) |arg| allocator.free(mem.sliceTo(arg, 0));
        allocator.free(os.argv);
    }

    var opts = getopt.init("a:bc");

    try testing.expectEqual('a', try opts.next());
    try testing.expectEqualDeep("yes", opts.optarg);
    try testing.expectEqual('b', try opts.next());
    try testing.expectEqualDeep(null, opts.optarg);
    try testing.expectEqual('c', try opts.next());
    try testing.expectEqualDeep(null, opts.optarg);
}

test "getopt optional parameter" {
    const testing = std.testing;
    const allocator = std.testing.allocator;
    const getopt = @This();

    os.argv = argv: {
        var argv: @TypeOf(os.argv) = try allocator.alloc([*:0]u8, 5);

        argv[0] = try allocator.dupeZ(u8, "program");
        argv[1] = try allocator.dupeZ(u8, "-a");
        argv[2] = try allocator.dupeZ(u8, "-b");
        argv[3] = try allocator.dupeZ(u8, "-c");
        argv[4] = try allocator.dupeZ(u8, "another value");

        break :argv argv;
    };
    defer {
        for (os.argv) |arg| allocator.free(mem.sliceTo(arg, 0));
        allocator.free(os.argv);
    }

    var opts = getopt.init("ab::c:");

    try testing.expectEqual('a', try opts.next());
    try testing.expectEqual(null, opts.optarg);
    try testing.expectEqual('b', try opts.next());
    try testing.expectEqual(null, opts.optarg);
    try testing.expectEqual('c', try opts.next());
    try testing.expectEqualDeep("another value", opts.optarg);
}

test "getopt separators" {
    const testing = std.testing;
    const allocator = std.testing.allocator;
    const getopt = @This();

    os.argv = argv: {
        var argv: @TypeOf(os.argv) = try allocator.alloc([*:0]u8, 5);

        argv[0] = try allocator.dupeZ(u8, "program");
        argv[1] = try allocator.dupeZ(u8, "-a=10");
        argv[2] = try allocator.dupeZ(u8, "-byes");
        argv[3] = try allocator.dupeZ(u8, "-c");
        argv[4] = try allocator.dupeZ(u8, "another value");

        break :argv argv;
    };
    defer {
        for (os.argv) |arg| allocator.free(mem.sliceTo(arg, 0));
        allocator.free(os.argv);
    }

    var opts = getopt.init("a:b:c:");

    try testing.expectEqual(try opts.next(), 'a');
    try testing.expectEqualDeep(opts.optarg, "10");
    try testing.expectEqual(try opts.next(), 'b');
    try testing.expectEqualDeep(opts.optarg, "yes");
    try testing.expectEqual(try opts.next(), 'c');
    try testing.expectEqualDeep(opts.optarg, "another value");
}

test "getopt optional parameter missing" {
    const testing = std.testing;
    const allocator = std.testing.allocator;
    const getopt = @This();

    os.argv = argv: {
        var argv: @TypeOf(os.argv) = try allocator.alloc([*:0]u8, 2);

        argv[0] = try allocator.dupeZ(u8, "program");
        argv[1] = try allocator.dupeZ(u8, "-a");

        break :argv argv;
    };
    defer {
        for (os.argv) |arg| allocator.free(mem.sliceTo(arg, 0));
        allocator.free(os.argv);
    }

    var opts = getopt.init("a:");

    try testing.expectError(Error.MissingParameter, opts.next());
}

test "getopt invalid option in cluster" {
    const testing = std.testing;
    const allocator = std.testing.allocator;
    const getopt = @This();

    os.argv = argv: {
        var argv: @TypeOf(os.argv) = try allocator.alloc([*:0]u8, 2);
        argv[0] = try allocator.dupeZ(u8, "program");
        argv[1] = try allocator.dupeZ(u8, "-abX");
        break :argv argv;
    };
    defer {
        for (os.argv) |arg| allocator.free(mem.sliceTo(arg, 0));
        allocator.free(os.argv);
    }

    var opts = getopt.init("ab");

    try testing.expectEqual('a', try opts.next());
    try testing.expectEqual('b', try opts.next());
    try testing.expectError(Error.InvalidOption, opts.next());
    try testing.expectEqual('X', opts.optopt);
}

test "getopt missing parameter in cluster" {
    const testing = std.testing;
    const allocator = std.testing.allocator;
    const getopt = @This();

    os.argv = argv: {
        var argv: @TypeOf(os.argv) = try allocator.alloc([*:0]u8, 2);
        argv[0] = try allocator.dupeZ(u8, "program");
        argv[1] = try allocator.dupeZ(u8, "-af");
        break :argv argv;
    };
    defer {
        for (os.argv) |arg| allocator.free(mem.sliceTo(arg, 0));
        allocator.free(os.argv);
    }

    var opts = getopt.init("af:");
    try testing.expectEqual('a', try opts.next());
    try testing.expectError(Error.MissingParameter, opts.next());
    try testing.expectEqual('f', opts.optopt);
}

test "getopt invalid standalone option" {
    const testing = std.testing;
    const allocator = std.testing.allocator;
    const getopt = @This();

    os.argv = argv: {
        var argv: @TypeOf(os.argv) = try allocator.alloc([*:0]u8, 2);
        argv[0] = try allocator.dupeZ(u8, "program");
        argv[1] = try allocator.dupeZ(u8, "-z");
        break :argv argv;
    };
    defer {
        for (os.argv) |arg| allocator.free(mem.sliceTo(arg, 0));
        allocator.free(os.argv);
    }

    var opts = getopt.init("abc");

    try testing.expectError(Error.InvalidOption, opts.next());
    try testing.expectEqual('z', opts.optopt);
}

test "permute argv in-place without allocations" {
    const testing = std.testing;
    const allocator = std.testing.allocator;

    os.argv = argv: {
        var argv_slice: @TypeOf(os.argv) = try allocator.alloc([*:0]u8, 7);
        argv_slice[0] = try allocator.dupeZ(u8, "program");
        argv_slice[1] = try allocator.dupeZ(u8, "pos1");
        argv_slice[2] = try allocator.dupeZ(u8, "-o");
        argv_slice[3] = try allocator.dupeZ(u8, "file.txt");
        argv_slice[4] = try allocator.dupeZ(u8, "pos2");
        argv_slice[5] = try allocator.dupeZ(u8, "-v");
        argv_slice[6] = try allocator.dupeZ(u8, "pos3");
        break :argv argv_slice;
    };
    defer {
        for (os.argv) |arg| allocator.free(mem.sliceTo(arg, 0));
        allocator.free(os.argv);
    }

    const optstring = "vo:";
    const first_positional_idx = partitionArgvInPlace(optstring);

    const expected_order = [_][]const u8{
        "program",
        "-o",
        "file.txt",
        "-v",
        "pos1",
        "pos2",
        "pos3",
    };

    var actual_order = try allocator.alloc([]const u8, os.argv.len);
    defer allocator.free(actual_order);
    for (os.argv, 0..) |arg, i|
        actual_order[i] = mem.sliceTo(arg, 0);

    try testing.expectEqual(4, first_positional_idx);
    try testing.expectEqualDeep(&expected_order, actual_order);
}

test "getopt optional arguments and positionals" {
    const testing = std.testing;
    const allocator = std.testing.allocator;

    os.argv = argv: {
        var argv_slice: @TypeOf(os.argv) = try allocator.alloc([*:0]u8, 7);
        argv_slice[0] = try allocator.dupeZ(u8, "program");
        argv_slice[1] = try allocator.dupeZ(u8, "pos1");
        argv_slice[2] = try allocator.dupeZ(u8, "-o");
        argv_slice[3] = try allocator.dupeZ(u8, "file.txt");
        argv_slice[4] = try allocator.dupeZ(u8, "pos2");
        argv_slice[5] = try allocator.dupeZ(u8, "-v");
        argv_slice[6] = try allocator.dupeZ(u8, "pos3");
        break :argv argv_slice;
    };
    defer {
        for (os.argv) |arg| allocator.free(mem.sliceTo(arg, 0));
        allocator.free(os.argv);
    }

    const optstring = "vo::";
    const first_positional_idx = partitionArgvInPlace(optstring);

    const expected_order = [_][]const u8{
        "program",
        "-o",
        "file.txt",
        "-v",
        "pos1",
        "pos2",
        "pos3",
    };

    var actual_order = try allocator.alloc([]const u8, os.argv.len);
    defer allocator.free(actual_order);
    for (os.argv, 0..) |arg, i|
        actual_order[i] = mem.sliceTo(arg, 0);

    try testing.expectEqual(4, first_positional_idx);
    try testing.expectEqualDeep(&expected_order, actual_order);
}

test "getopt usagestring generation" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const getopt = @This();

    os.argv = argv: {
        var argv_slice: @TypeOf(os.argv) = try allocator.alloc([*:0]u8, 1);
        argv_slice[0] = try allocator.dupeZ(u8, "program");
        break :argv argv_slice;
    };
    defer {
        for (os.argv) |arg| allocator.free(mem.sliceTo(arg, 0));
        allocator.free(os.argv);
    }

    {
        const opts = getopt.init("abc");
        try testing.expectEqualStrings("[-abc]", opts.usagestring);
    }

    {
        const opts = getopt.init("a:b:");
        try testing.expectEqualStrings("[-a <value>] [-b <value>]", opts.usagestring);
    }

    {
        const opts = getopt.init("c::d::");
        try testing.expectEqualStrings("[-c ?<value>] [-d ?<value>]", opts.usagestring);
    }

    {
        const opts = getopt.init("h:i::j:fgk");
        const expected = "[-fgk] [-h <value>] [-j <value>] [-i ?<value>]";
        try testing.expectEqualStrings(expected, opts.usagestring);
    }

    {
        const opts = getopt.init("");
        try testing.expectEqualStrings("", opts.usagestring);
    }

    {
        const opts = getopt.init("a:bcde:f");
        const expected = "[-bcdf] [-a <value>] [-e <value>]";
        try testing.expectEqualStrings(expected, opts.usagestring);
    }
}
