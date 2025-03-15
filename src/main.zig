const std = @import("std");
const zglfw = @import("zglfw");
const GUI = @import("gui.zig").GUI;
const window_title = "Escape the darkness";

const Meshes = @import("engine/mesh.zig").Meshes;
const Engine = @import("engine/engine.zig").Engine;
const Grid = @import("engine/mesh/grid.zig").Grid;

const echolocation_shader = @embedFile("engine/shader/echolocation.wgsl");
const debug_shader = @embedFile("engine/shader/debug.wgsl");

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
    defer meshes.deinit();

    const monkey_mesh = try meshes.loadMesh("monkey.gltf");
    // const cube_mesh = try meshes.loadMesh("cube.gltf");
    // const torus_mesh = try meshes.loadMesh("torus.gltf");

    const grid_data = try Grid.init(allocator, 100, 1.0);
    defer grid_data.deinit();

    // const grid_mesh = try meshes.addGeneratedMesh(grid_data.vertices.items, grid_data.indices.items);

    var engine = try Engine.init(allocator, window, &meshes);
    defer engine.deinit();

    const echolocation_material = engine.createMaterial(echolocation_shader);
    // const debug_material = engine.createMaterialDebug(debug_shader);

    var monkey = try engine.addMeshInstance(&echolocation_material, monkey_mesh);
    monkey.addInstance(.{
        .position = .{ 0, 0, 0 },
        .rotation = .{ 0, 0, 0, 1 },
        .scale = .{ 1, 1, 1 },
    });
    monkey.addInstance(.{ .position = .{ 1, 0, 0 }, .rotation = .{ 0, 0, 0, 1 }, .scale = .{ 1, 1, 1 } });

    // _ = try engine.addMeshInstance(&echolocation_material, cube_mesh);
    // _ = try engine.addMeshInstance(&echolocation_material, torus_mesh);
    // _ = try engine.addMeshInstance(&debug_material, grid_mesh);

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        zglfw.pollEvents();
        // try engine.beginPass();
        try engine.draw();
        // try engine.endPass();
    }
}
