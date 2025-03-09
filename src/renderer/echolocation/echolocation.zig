const std = @import("std");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zm = @import("zmath");
const math = std.math;

const Meshes = @import("../mesh_loader.zig").Meshes;
const Mesh = @import("../mesh_loader.zig").Mesh;
const Vertex = @import("../mesh_loader.zig").Vertex;
const GPUBuffer = @import("../buffer.zig").GPUBuffer;
const GPULayout = @import("../layout.zig").GPULayout;
const Pipeline = @import("../pipeline.zig").Pipeline;
const Camera = @import("../camera.zig");

pub fn renderEcholocation(gctx: *zgpu.GraphicsContext, pass: wgpu.RenderPassEncoder, pip: *const Pipeline, vertex_buffer: *const GPUBuffer(Vertex), index_buffer: *const GPUBuffer(u32), meshes: *Meshes) void {
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
                meshes.meshes.items[0].num_indices,
                1,
                meshes.meshes.items[0].index_offset,
                meshes.meshes.items[0].vertex_offset,
                0,
            );
        }
    }
}
