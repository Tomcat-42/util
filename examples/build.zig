const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "main",
        .root_module = b.createModule(.{
            .root_source_file = b.path("main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "util",
                    .module = b.dependency(
                        "util",
                        .{
                            .target = target,
                            .optimize = optimize,
                        },
                    ).module("util"),
                },
            },
        }),
    });

    b.installArtifact(exe);
}
