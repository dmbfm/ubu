const std = @import("std");

const BuildOptions = struct {
    target: std.zig.CrossTarget,
    mode: std.builtin.Mode,
};

const ubu_pkg = std.build.Pkg{
    .name = "ubu",
    .source = .{ .path = "src/ubu.zig" },
};

pub fn add_example(b: *std.build.Builder, opts: BuildOptions, comptime name: []const u8, comptime src: []const u8) void {
    const exe = b.addExecutable(name, src);
    exe.setTarget(opts.target);
    exe.setBuildMode(opts.mode);
    exe.addPackage(ubu_pkg);
    exe.install();

    const run_cmd = exe.run();
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step(name, "Run example " ++ name);
    run_step.dependOn(&run_cmd.step);
}

pub fn build(b: *std.build.Builder) void {
    var opts = BuildOptions{
        .target = b.standardTargetOptions(.{}),
        .mode = b.standardReleaseOptions(),
    };

    const lib = b.addStaticLibrary("ubu", "src/ubu.zig");
    lib.setBuildMode(opts.mode);
    lib.install();

    const exe_tests = b.addTest("src/ubu.zig");
    exe_tests.setTarget(opts.target);
    exe_tests.setBuildMode(opts.mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);

    add_example(b, opts, "example-gradient-test", "examples/image/gradient_test.zig");
    add_example(b, opts, "example-image-invert", "examples/image/image_invert.zig");
}
