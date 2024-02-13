const std = @import("std");

pub fn build(b: *std.Build) void {
    const exe = b.addExecutable(.{ .name = "main", .root_source_file = .{ .path = "main.zig" }, .target = b.host });
    exe.linkLibC();
    exe.linkSystemLibrary("gdi32");
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const zigimg = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zigimg", zigimg.module("zigimg"));

    const tracy_client_source_path = std.Build.LazyPath{ .path = std.fs.path.join(b.allocator, &.{ "H:\\Repos\\SpaceInvaders(FromPlanetZig)\\tracy\\public", "TracyClient.cpp" }) catch unreachable };
    exe.addIncludePath(tracy_client_source_path);
    exe.addCSourceFile(.{
        .file = tracy_client_source_path,
        .flags = &[_][]const u8{
            "-DTRACY_ENABLE=1",
            // MinGW doesn't have all the newfangled windows features,
            // so we need to pretend to have an older windows version.
            "-D_WIN32_WINNT=0x601",
            "-fno-sanitize=undefined",
        },
    });
    exe.linkSystemLibrary("c++");
    exe.linkSystemLibrary("dbghelp");
    exe.linkSystemLibrary("ws2_32");
    b.installArtifact(exe);
    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "run the app");
    run_step.dependOn(&run_exe.step);
}
