const std = @import("std");
const zglfw = @import("zglfw");
const GUI = @import("gui.zig").GUI;
const window_title = "Escape the darkness";

const Meshes = @import("renderer/mesh_loader.zig").Meshes;
const Engine = @import("renderer/engine.zig").Engine;

const echolocation_shader = @embedFile("renderer/echolocation/echolocation.wgsl");

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

    var meshes = try Meshes.init(allocator);
    const monkey_mesh = try meshes.loadMesh("monkey.gltf");
    const cube_mesh = try meshes.loadMesh("cube.gltf");
    defer meshes.deinit();

    var engine = try Engine.init(allocator, window, &meshes);
    defer engine.deinit();

    const echolocation_material = engine.createMaterial(echolocation_shader);
    const debug_material = engine.createMaterialDebug(echolocation_shader);

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        zglfw.pollEvents();
        try engine.drawMesh(cube_mesh, &echolocation_material);
        try engine.drawMesh(monkey_mesh, &debug_material);
    }
}
