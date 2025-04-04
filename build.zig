const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const exe = b.addExecutable(.{
        .name = "sdl3_zig_probe",
        .root_module = exe_mod,
    });

    // DEP: SDL3
    if (b.systemIntegrationOption("sdl", .{ .default = false })) {
        exe_mod.linkSystemLibrary("SDL3", .{});
    } else {
        const sdl_dep = b.dependency("sdl", .{
            .target = target,
            .optimize = optimize,
            .preferred_link_mode = .static,
        });
        const sdl_lib = sdl_dep.artifact("SDL3");
        exe_mod.linkLibrary(sdl_lib);
    }

    // DEP: freetype2
    if (b.systemIntegrationOption("freetype", .{ .default = false })) {
        exe_mod.linkSystemLibrary("freetype2", .{});
    } else {
        const freetype_dep = b.dependency("freetype", .{
            .target = target,
            .optimize = optimize,
        });
        exe_mod.linkLibrary(freetype_dep.artifact("freetype"));
    }

    // DEP: harfbuzz
    if (b.systemIntegrationOption("harfbuzz", .{ .default = false })) {
        exe_mod.linkSystemLibrary("harfbuzz", .{});
    } else {
        const harfbuzz_dep = b.dependency("harfbuzz", .{
            .target = target,
            .optimize = optimize,
        });
        exe_mod.linkLibrary(harfbuzz_dep.artifact("harfbuzz"));
        exe.addIncludePath(harfbuzz_dep.path("include"));
        exe.addIncludePath(harfbuzz_dep.path("src"));
    }
    exe_mod.addCMacro("TTF_USE_HARFBUZZ", "1");

    // DEP: SDL3_ttf
    // TODO: use system SDL3_ttf when (if?) it lands on Arch
    const sdl_ttf_dep = b.dependency("sdl_ttf", .{
        .target = target,
        .optimize = optimize,
    });
    exe.addIncludePath(sdl_ttf_dep.path("include"));
    exe.addIncludePath(sdl_ttf_dep.path("src"));
    exe.installHeadersDirectory(sdl_ttf_dep.path("include"), "", .{});
    exe.addCSourceFiles(.{
        .root = sdl_ttf_dep.path("src"),
        .files = &.{
            "SDL_gpu_textengine.c",
            "SDL_hashtable.c",
            "SDL_hashtable_ttf.c",
            "SDL_renderer_textengine.c",
            "SDL_surface_textengine.c",
            "SDL_ttf.c",
        },
    });

    // TODO: use system Yoga when (if?) it lands on Arch
    {
        const yoga_files = .{
            "YGConfig.cpp",
            "YGEnums.cpp",
            "YGNode.cpp",
            "YGNodeLayout.cpp",
            "YGNodeStyle.cpp",
            "YGPixelGrid.cpp",
            "YGValue.cpp",
            "algorithm/AbsoluteLayout.cpp",
            "algorithm/Baseline.cpp",
            "algorithm/Cache.cpp",
            "algorithm/CalculateLayout.cpp",
            "algorithm/FlexLine.cpp",
            "algorithm/PixelGrid.cpp",
            "config/Config.cpp",
            "debug/AssertFatal.cpp",
            "debug/Log.cpp",
            "event/event.cpp",
            "node/LayoutResults.cpp",
            "node/Node.cpp",
        };
        const yoga_flags = .{
            "--std=c++20",
            "-Wall",
            "-Wextra",
            "-Werror",
        };
        const yoga_dep = b.dependency("yoga", .{
            .target = target,
            .optimize = optimize,
        });
        exe.addCSourceFiles(.{
            .root = yoga_dep.path("yoga"),
            .files = &yoga_files,
            .flags = &yoga_flags,
        });
        exe.installHeadersDirectory(yoga_dep.path("yoga"), "yoga", .{
            .include_extensions = &.{".h"},
        });
        exe.linkLibCpp();
        exe.addIncludePath(yoga_dep.path(""));
    }

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
