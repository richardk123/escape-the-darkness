const std = @import("std");
const zglfw = @import("zglfw");
const MapEditorGui = @import("editor/map_editor_gui.zig").MapEditorGui;
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

    var gui = MapEditorGui.init(allocator, window, &engine);
    defer gui.deinit();

    var free_camera = FreeCamera.init(&engine);
    var player = try Player.init(&engine);
    defer player.deinit();

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        zglfw.pollEvents();
        free_camera.update();
        engine.renderer.beginFrame();
        try engine.update();
        try gui.update();
        player.update();
        engine.renderer.finishFrame();
    }
}
