const std = @import("std");
const zglfw = @import("zglfw");
const GUI = @import("gui.zig").GUI;
const window_title = "Escape the darkness";
const zm = @import("zmath");

const MeshType = @import("engine/mesh.zig").MeshType;
const Engine = @import("engine/engine.zig").Engine;
const FreeCamera = @import("utils/camera_free.zig").FreeCamera;
const MaterialType = @import("engine/material.zig").MaterialType;
const Player = @import("player/player.zig").Player;

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

    var monkey = try engine.addMeshRenderer(MaterialType.echolocation, MeshType.monkey);
    const count = 10;
    const radius: f32 = 10.0;
    for (0..count) |i| {
        const angle = @as(f32, @floatFromInt(i)) / @as(f32, count) * 2.0 * std.math.pi;
        const x = std.math.cos(angle) * radius;
        const z = std.math.sin(angle) * radius;
        // _ = monkey.addInstance(.{ x, 2.0, z }, zm.quatFromRollPitchYaw(1.14, 1.14, 0), null);
        _ = monkey.addInstance(.{ x, 2.0, z }, null, null);
    }

    var floor = try engine.addMeshRenderer(MaterialType.echolocation, MeshType.floor);
    _ = floor.addInstance(.{ 0.0, 0.0, 0.0 }, null, null);

    // var plane_echo = try engine.addMeshRenderer(MaterialType.echolocation, MeshType.plane);
    // _ = plane_echo.addInstance(.{ 0.0, 0.0, 0.0 }, null, .{ 5000, 5000, 5000 });

    var terrain = try engine.addMeshRenderer(MaterialType.echolocation, MeshType.terrain);
    _ = terrain.addInstance(.{ 0.0, 0.1, 50.0 }, null, null);

    // var debug_sound_quad = try engine.addMeshRenderer(MaterialType.sound_texture, MeshType.plane);
    // _ = debug_sound_quad.addInstance(.{ 0.0, 0.1, 0.0 }, null, null);

    var free_camera = FreeCamera.init(&engine);
    var player = try Player.init(&engine);
    defer player.deinit();

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        zglfw.pollEvents();
        gui.update();
        free_camera.update();
        engine.renderer.beginFrame();
        try engine.update();
        try gui.draw();
        player.update();
        engine.renderer.finishFrame();
    }
}
