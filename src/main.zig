const std = @import("std");
const zglfw = @import("zglfw");
const GUI = @import("gui.zig").GUI;
const window_title = "Escape the darkness";

const MeshType = @import("engine/mesh.zig").MeshType;
const Engine = @import("engine/engine.zig").Engine;
const FreeCamera = @import("utils/camera_free.zig").FreeCamera;
const MaterialType = @import("engine/material.zig").MaterialType;

pub fn main() !void {
    try zglfw.init();
    defer zglfw.terminate();

    // Change current working directory to where the executable is located.
    {
        var buffer: [1024]u8 = undefined;
        const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
        std.posix.chdir(path) catch {};
    }

    zglfw.windowHint(.client_api, .no_api);

    const window = try zglfw.Window.create(1600, 1000, window_title, null);
    defer window.destroy();
    window.setSizeLimits(400, 400, -1, -1);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var engine = try Engine.init(allocator, window);
    defer engine.deinit();

    var gui = GUI.init(allocator, window, &engine);
    defer gui.deinit();

    var monkey = try engine.addMeshRenderer(MaterialType.echolocation, MeshType.cube);
    for (0..5) |i| {
        const dist: f32 = @as(f32, @floatFromInt(i)) + 1.2;
        monkey.addInstance(.{ .position = .{ dist * dist, 2.0, dist * -10.0 + dist }, .rotation = .{ 0, 0, 0, 1 }, .scale = .{ 1, 1, 1 } });
        monkey.addInstance(.{ .position = .{ -dist * dist, 2.0, dist * -10.0 + dist }, .rotation = .{ 0, 0, 0, 1 }, .scale = .{ 1, 1, 1 } });
    }

    var plane_echo = try engine.addMeshRenderer(MaterialType.echolocation, MeshType.plane);
    plane_echo.addInstance(.{ .position = .{ 0.0, -0.5, 0.0 }, .rotation = .{ 0, 0, 0, 1 }, .scale = .{ 5000, 5000, 5000 } });

    var terrain = try engine.addMeshRenderer(MaterialType.echolocation, MeshType.terrain);
    terrain.addInstance(.{ .position = .{ 0.0, 0.0, -50.0 }, .rotation = .{ 0, 0, 0, 1 }, .scale = .{ 1, 1, 1 } });

    var debiug_sound_quad = try engine.addMeshRenderer(MaterialType.sound_texture, MeshType.plane);
    debiug_sound_quad.addInstance(.{ .position = .{ 0.0, 0.1, 0.0 }, .rotation = .{ 0, 0, 0, 1 }, .scale = .{ 1, 1, 1 } });

    var free_camera = FreeCamera.init(&engine);

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        zglfw.pollEvents();
        gui.update();
        free_camera.update();
        engine.renderer.beginFrame();
        try engine.update();
        try gui.draw();
        engine.renderer.finishFrame();
    }
}
