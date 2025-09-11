const std = @import("std");
const fs = std.fs;
const zon = std.zon;
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Modules
    const util_mod = b.addModule("util", .{
        .root_source_file = b.path("src/util.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Targets
    const util_lib = b.addLibrary(.{
        .name = "util",
        .root_module = util_mod,
        .linkage = .static,
    });
    const util_test = b.addTest(.{ .root_module = util_mod });
    const util_check = b.addLibrary(.{ .name = "util_check", .root_module = util_mod });

    // Install
    b.installArtifact(util_lib);

    // Test
    const run_util_tests = b.addRunArtifact(util_test);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_util_tests.step);

    // Docs
    const util_doc = b.addInstallDirectory(.{
        .source_dir = util_lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "doc",
    });
    const doc_step = b.step("doc", "Generate documentation");
    doc_step.dependOn(&util_doc.step);

    // Clean
    const clean_step = b.step("clean", "Remove build artifacts");
    clean_step.dependOn(&b.addRemoveDirTree(b.path(fs.path.basename(b.install_path))).step);
    if (builtin.os.tag != .windows)
        clean_step.dependOn(&b.addRemoveDirTree(b.path(".zig-cache")).step);

    // Check
    const check_step = b.step("check", "Check that the build artifacts are up-to-date");
    check_step.dependOn(&util_check.step);
}
