const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{ .name = "main", .root_source_file = .{ .path = "main.zig" }, .target = b.host, .optimize = optimize });
    exe.linkLibC();
    exe.linkSystemLibrary("gdi32");
    const zigimg = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("zigimg", zigimg.module("zigimg"));

    const tracy = b.option([]const u8, "tracy", "When tracy path is passed in will run with tracing");

    if (tracy) |path| {
        const tracy_client_source_path = std.Build.LazyPath{ .path = std.fs.path.join(b.allocator, &.{ path, "public", "TracyClient.cpp" }) catch unreachable };
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
    }
    const options = b.addOptions();
    options.addOption(bool, "tracy", tracy != null);
    exe.root_module.addOptions("config", options);

    b.installArtifact(exe);
    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "run the app");
    run_step.dependOn(&run_exe.step);
}
