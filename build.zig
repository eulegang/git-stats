const std = @import("std");

pub fn build(b: *std.Build) void {
    const sym = b.addModule("sym", .{ .source_file = .{ .path = "./deps/sym/src/main.zig" } });
    const stats = b.addModule("stats", .{
        .source_file = .{ .path = "src/main.zig" },
        .dependencies = &[_]std.Build.ModuleDependency{
            .{ .name = "sym", .module = sym },
        },
    });

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "git-stats",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.addModule("sym", sym);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "test/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    unit_tests.addModule("sym", sym);
    unit_tests.addModule("stats", stats);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
