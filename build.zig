const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create build options for both executables
    const content_dir = "content/";
    const options = b.addOptions();
    options.addOption([]const u8, "content_dir", content_dir);

    // Build the main game executable
    const game_exe = b.addExecutable(.{
        .name = "game",
        .root_source_file = b.path("src/game.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Build the map editor executable
    const editor_exe = b.addExecutable(.{
        .name = "map-editor",
        .root_source_file = b.path("src/map_editor.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add build options to both executables
    game_exe.root_module.addOptions("build_options", options);
    editor_exe.root_module.addOptions("build_options", options);

    // Add shared dependencies for both executables
    addDependencies(b, game_exe, target);
    addDependencies(b, editor_exe, target);

    // Install content directory for both executables
    const install_content_step = b.addInstallDirectory(.{
        .source_dir = b.path(content_dir),
        .install_dir = .{ .custom = "" },
        .install_subdir = b.pathJoin(&.{ "bin", content_dir }),
    });
    game_exe.step.dependOn(&install_content_step.step);
    editor_exe.step.dependOn(&install_content_step.step);

    // Install both executables
    b.installArtifact(game_exe);
    b.installArtifact(editor_exe);

    // Create run steps for both executables
    const run_game_cmd = b.addRunArtifact(game_exe);
    run_game_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_game_cmd.addArgs(args);
    }

    const run_editor_cmd = b.addRunArtifact(editor_exe);
    run_editor_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_editor_cmd.addArgs(args);
    }

    // Add run steps
    const run_game_step = b.step("run-game", "Run the game");
    run_game_step.dependOn(&run_game_cmd.step);

    const run_editor_step = b.step("run-editor", "Run the map editor");
    run_editor_step.dependOn(&run_editor_cmd.step);

    // Add a general run step that defaults to the game
    const run_step = b.step("run", "Run the game (alias for run-game)");
    run_step.dependOn(&run_game_cmd.step);

    // Setup tests
    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/game.zig"),
        .target = target,
        .optimize = optimize,
    });

    addDependencies(b, exe_unit_tests, target);
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

fn addDependencies(b: *std.Build, artifact: *std.Build.Step.Compile, target: std.Build.ResolvedTarget) void {
    // Add all the dependencies required by both executables

    const zglfw = b.dependency("zglfw", .{ .target = target });
    artifact.root_module.addImport("zglfw", zglfw.module("root"));
    artifact.linkLibrary(zglfw.artifact("glfw"));

    @import("zgpu").addLibraryPathsTo(artifact);
    const zgpu = b.dependency("zgpu", .{ .target = target });
    artifact.root_module.addImport("zgpu", zgpu.module("root"));
    artifact.linkLibrary(zgpu.artifact("zdawn"));

    const zaudio = b.dependency("zaudio", .{});
    artifact.root_module.addImport("zaudio", zaudio.module("root"));
    artifact.linkLibrary(zaudio.artifact("miniaudio"));

    const zstbi = b.dependency("zstbi", .{
        .target = target,
    });
    artifact.root_module.addImport("zstbi", zstbi.module("root"));
    artifact.linkLibrary(zstbi.artifact("zstbi"));

    const zgui = b.dependency("zgui", .{
        .target = target,
        .backend = .glfw_wgpu,
    });
    artifact.root_module.addImport("zgui", zgui.module("root"));
    artifact.linkLibrary(zgui.artifact("imgui"));

    const zmath = b.dependency("zmath", .{
        .target = target,
    });
    artifact.root_module.addImport("zmath", zmath.module("root"));

    const zmesh = b.dependency("zmesh", .{
        .target = target,
    });
    artifact.root_module.addImport("zmesh", zmesh.module("root"));
    artifact.linkLibrary(zmesh.artifact("zmesh"));

    // Platform-specific library paths
    switch (target.result.os.tag) {
        .windows => {
            if (target.result.cpu.arch.isX86()) {
                if (target.result.abi.isGnu() or target.result.abi.isMusl()) {
                    if (b.lazyDependency("system_sdk", .{})) |system_sdk| {
                        artifact.addLibraryPath(system_sdk.path("windows/lib/x86_64-windows-gnu"));
                    }
                }
            }
        },
        .macos => {
            if (b.lazyDependency("system_sdk", .{})) |system_sdk| {
                artifact.addLibraryPath(system_sdk.path("macos12/usr/lib"));
                artifact.addFrameworkPath(system_sdk.path("macos12/System/Library/Frameworks"));
            }
        },
        .linux => {
            if (target.result.cpu.arch.isX86()) {
                if (b.lazyDependency("system_sdk", .{})) |system_sdk| {
                    artifact.addLibraryPath(system_sdk.path("linux/lib/x86_64-linux-gnu"));
                }
            } else if (target.result.cpu.arch == .aarch64) {
                if (b.lazyDependency("system_sdk", .{})) |system_sdk| {
                    artifact.addLibraryPath(system_sdk.path("linux/lib/aarch64-linux-gnu"));
                }
            }
        },
        else => {},
    }
}
