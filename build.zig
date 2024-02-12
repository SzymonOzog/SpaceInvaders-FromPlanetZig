const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{ .name = "main", .root_source_file = .{ .path = "main.zig" }, .target = b.host });
    exe.linkLibC();
    exe.linkSystemLibrary("gdi32");
    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "run the app");
    run_step.dependOn(&run_exe.step);
}
