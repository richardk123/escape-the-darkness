const std = @import("std");
const zglfw = @import("zglfw");
const GUI = @import("gui.zig").GUI;
const window_title = "Escape the darkness";

const GPUBuffer = @import("renderer/buffer.zig").GPUBuffer;
const GPULayout = @import("renderer/layout.zig").GPULayout;
const Vertex = @import("renderer/mesh_loader.zig").Vertex;
const Meshes = @import("renderer/mesh_loader.zig").Meshes;
const Mesh = @import("renderer/mesh_loader.zig").Mesh;
const Pipeline = @import("renderer/pipeline.zig").Pipeline;
const Renderer = @import("renderer/renderer.zig").Renderer;

const Echolocation = @import("renderer/echolocation/echolocation.zig");
const GridFloor = @import("renderer/grid_floor/grid_floor.zig");

const vs_shader = @embedFile("renderer/echolocation/echolocation.wgsl");
const vs_shader_floor = @embedFile("renderer/grid_floor/grid_floor.wgsl");

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

    var renderer = try Renderer.init(allocator, window);
    defer renderer.deinit(allocator);

    const total_num_vertices = @as(u32, @intCast(meshes.vertices.items.len));
    const total_num_indices = @as(u32, @intCast(meshes.indices.items.len));

    const gctx = renderer.gctx;

    // Create a vertex buffer.
    const vertex_buffer = GPUBuffer(Vertex).init(gctx, .{ .copy_dst = true, .vertex = true }, total_num_vertices);
    vertex_buffer.write(gctx, meshes.vertices.items);

    // Create an index buffer.
    const index_buffer = GPUBuffer(u32).init(gctx, .{ .copy_dst = true, .index = true }, total_num_indices);
    index_buffer.write(gctx, meshes.indices.items);

    const pipeline = Pipeline.initRenderPipeline(gctx, vs_shader);

    var floorData = try GridFloor.FloorData.init(allocator);
    defer floorData.deinit();

    const floor_vertext_buffer = GPUBuffer(GridFloor.Vertex).init(gctx, .{ .copy_dst = true, .vertex = true }, floorData.getNumberOfVertices());
    floor_vertext_buffer.write(gctx, floorData.vertices.items);

    const floor_index_buffer = GPUBuffer(u32).init(gctx, .{ .copy_dst = true, .index = true }, floorData.getNumberOfVertices());
    floor_index_buffer.write(gctx, floorData.indices.items);

    const floor_pipeline = Pipeline.initRenderPipeline(gctx, vs_shader_floor);

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        zglfw.pollEvents();

        var frame = renderer.beginFrame();
        const pass = try frame.beginRenderPass();

        Echolocation.renderEcholocation(gctx, pass, &pipeline, &vertex_buffer, &index_buffer, &meshes);
        GridFloor.renderEcholocation(gctx, pass, &floor_pipeline, &floor_vertext_buffer, &floor_index_buffer, &floorData);
        try frame.end();
    }
}
