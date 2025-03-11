const std = @import("std");
const zglfw = @import("zglfw");

const Renderer = @import("common/renderer.zig").Renderer;
const GPUBuffer = @import("common/buffer.zig").GPUBuffer;
const Material = @import("material.zig").Material;
const Camera = @import("camera.zig");
const mesh = @import("mesh.zig");

pub const Engine = struct {
    allocator: std.mem.Allocator,
    meshes: *mesh.Meshes,
    renderer: Renderer,
    vertex_buffer: GPUBuffer(mesh.Vertex),
    index_buffer: GPUBuffer(u32),

    pub fn init(allocator: std.mem.Allocator, window: *zglfw.Window, meshes: *mesh.Meshes) !Engine {
        const renderer = try Renderer.init(allocator, window);
        const gctx = renderer.gctx;

        const total_num_vertices = @as(u32, @intCast(meshes.vertices.items.len));
        const total_num_indices = @as(u32, @intCast(meshes.indices.items.len));

        // Create a vertex buffer.
        const vertex_buffer = GPUBuffer(mesh.Vertex).init(gctx, .{ .copy_dst = true, .vertex = true }, total_num_vertices);
        vertex_buffer.write(gctx, meshes.vertices.items);

        // Create an index buffer.
        const index_buffer = GPUBuffer(u32).init(gctx, .{ .copy_dst = true, .index = true }, total_num_indices);
        index_buffer.write(gctx, meshes.indices.items);

        return Engine{
            .allocator = allocator,
            .renderer = renderer,
            .meshes = meshes,
            .vertex_buffer = vertex_buffer,
            .index_buffer = index_buffer,
        };
    }

    pub fn createMaterialDebug(self: *Engine, shader: [*:0]const u8) Material(mesh.Vertex) {
        const gctx = self.renderer.gctx;
        return Material(mesh.Vertex).init(gctx, shader, .line_list);
    }

    pub fn createMaterial(self: *Engine, shader: [*:0]const u8) Material(mesh.Vertex) {
        const gctx = self.renderer.gctx;
        return Material(mesh.Vertex).init(gctx, shader, .triangle_list);
    }

    pub fn beginPass(self: *Engine) !void {
        try self.renderer.beginPass();
    }

    pub fn endPass(self: *Engine) !void {
        try self.renderer.endPass();
    }

    pub fn draw(self: *Engine, mesh_index: usize, material: *const Material(mesh.Vertex)) !void {
        const gctx = self.renderer.gctx;
        pass: {
            const pass = self.renderer.pass orelse break :pass;
            const vb_info = gctx.lookupResourceInfo(self.vertex_buffer.gpu_buffer) orelse break :pass;
            const ib_info = gctx.lookupResourceInfo(self.index_buffer.gpu_buffer) orelse break :pass;
            const pipeline = gctx.lookupResource(material.pipeline) orelse break :pass;
            const bind_group = gctx.lookupResource(material.bind_group) orelse break :pass;

            pass.setVertexBuffer(0, vb_info.gpuobj.?, 0, vb_info.size);
            pass.setIndexBuffer(ib_info.gpuobj.?, .uint32, 0, ib_info.size);
            pass.setPipeline(pipeline);

            const memOffset = Camera.calculateCamera(gctx);

            pass.setBindGroup(0, bind_group, &.{memOffset});
            pass.drawIndexed(
                self.meshes.meshes.items[mesh_index].num_indices,
                1,
                self.meshes.meshes.items[mesh_index].index_offset,
                self.meshes.meshes.items[mesh_index].vertex_offset,
                0,
            );
        }
    }

    pub fn deinit(self: *Engine) void {
        self.renderer.deinit(self.allocator);
    }
};
