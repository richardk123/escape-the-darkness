const std = @import("std");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zm = @import("zmath");
const math = std.math;

const GPUBuffer = @import("../buffer.zig").GPUBuffer;
const GPULayout = @import("../layout.zig").GPULayout;
const Pipeline = @import("../pipeline.zig").Pipeline;
const Camera = @import("../camera.zig");
const Vertex = @import("../mesh_loader.zig").Vertex;

pub const FloorData = struct {
    vertices: std.ArrayList(Vertex),
    indices: std.ArrayList(u32),

    pub fn init(allocator: std.mem.Allocator) !FloorData {
        var vertices = std.ArrayList(Vertex).init(allocator);
        var indices = std.ArrayList(u32).init(allocator);
        try vertices.ensureTotalCapacity(400);
        try indices.ensureTotalCapacity(400);

        for (0..100) |i| {
            vertices.appendAssumeCapacity(.{
                .position = [_]f32{ @floatFromInt(i), 0.0, 0.0 },
                .normal = [_]f32{ 0.0, 0.0, 0.0 },
            });
            vertices.appendAssumeCapacity(.{
                .position = [_]f32{ @floatFromInt(i), 0.0, 99.0 },
                .normal = [_]f32{ 0.0, 0.0, 0.0 },
            });
            vertices.appendAssumeCapacity(.{
                .position = [_]f32{ 0.0, 0.0, @floatFromInt(i) },
                .normal = [_]f32{ 0.0, 0.0, 0.0 },
            });
            vertices.appendAssumeCapacity(.{
                .position = [_]f32{ 99.0, 0.0, @floatFromInt(i) },
                .normal = [_]f32{ 0.0, 0.0, 0.0 },
            });
            indices.appendAssumeCapacity(@as(u32, @intCast(i * 4 + 0)));
            indices.appendAssumeCapacity(@as(u32, @intCast(i * 4 + 1)));
            indices.appendAssumeCapacity(@as(u32, @intCast(i * 4 + 2)));
            indices.appendAssumeCapacity(@as(u32, @intCast(i * 4 + 3)));
        }

        return FloorData{
            .vertices = vertices,
            .indices = indices,
        };
    }

    pub fn getNumberOfVertices(self: *FloorData) u32 {
        return @as(u32, @intCast(self.vertices.items.len));
    }

    pub fn deinit(self: *FloorData) void {
        self.vertices.deinit();
        self.indices.deinit();
    }
};

pub fn renderEcholocation(gctx: *zgpu.GraphicsContext, pass: wgpu.RenderPassEncoder, pip: *const Pipeline, vertex_buffer: *const GPUBuffer(Vertex), index_buffer: *const GPUBuffer(u32), floorData: *FloorData) void {
    pass: {
        const vb_info = gctx.lookupResourceInfo(vertex_buffer.gpu_buffer) orelse break :pass;
        const ib_info = gctx.lookupResourceInfo(index_buffer.gpu_buffer) orelse break :pass;
        const pipeline = gctx.lookupResource(pip.pipeline) orelse break :pass;
        const bind_group = gctx.lookupResource(pip.bind_group) orelse break :pass;

        pass.setVertexBuffer(0, vb_info.gpuobj.?, 0, vb_info.size);
        pass.setIndexBuffer(ib_info.gpuobj.?, .uint32, 0, ib_info.size);
        pass.setPipeline(pipeline);

        {
            const memOffset = Camera.calculateCamera(gctx);

            pass.setBindGroup(0, bind_group, &.{memOffset});
            pass.drawIndexed(
                floorData.getNumberOfVertices(),
                1,
                0,
                0,
                0,
            );
        }
    }
}
