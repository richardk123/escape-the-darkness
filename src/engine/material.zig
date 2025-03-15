const std = @import("std");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zm = @import("zmath");
const GPUBuffer = @import("common/buffer.zig").GPUBuffer;
const GPULayout = @import("common/layout.zig").GPULayout;
const Instance = @import("mesh_instance.zig").Instance;

pub fn Material(comptime T: type) type {
    return struct {
        pipeline: zgpu.RenderPipelineHandle,
        bind_group: zgpu.BindGroupHandle,

        const Self = @This();

        pub fn init(
            gctx: *zgpu.GraphicsContext,
            instance_buffer: GPUBuffer(Instance),
            shader: [*:0]const u8,
            topology: wgpu.PrimitiveTopology,
        ) Self {
            // Create a bind group layout needed for our render pipeline.
            const bind_group_layout = gctx.createBindGroupLayout(&.{
                zgpu.bufferEntry(0, .{ .vertex = true }, .uniform, true, 0),
                zgpu.bufferEntry(1, .{ .vertex = true }, .read_only_storage, false, 0),
            });
            defer gctx.releaseResource(bind_group_layout);

            const bind_group = gctx.createBindGroup(bind_group_layout, &.{
                .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = @sizeOf(zm.Mat) },
                .{ .binding = 1, .buffer_handle = instance_buffer.gpu_buffer, .offset = 0, .size = (@sizeOf(Instance) * instance_buffer.total_number) },
            });

            const pipeline_layout = gctx.createPipelineLayout(&.{bind_group_layout});
            defer gctx.releaseResource(pipeline_layout);

            const shader_source = zgpu.createWgslShaderModule(gctx.device, shader, "shader_source");
            defer shader_source.release();

            const color_targets = [_]wgpu.ColorTargetState{.{
                .format = zgpu.GraphicsContext.swapchain_format,
            }};

            const vertex_layouts = GPULayout(T).createVertexBufferLayouts();

            const pipeline_descriptor = wgpu.RenderPipelineDescriptor{
                .vertex = wgpu.VertexState{
                    .module = shader_source,
                    .entry_point = "vs",
                    .buffer_count = vertex_layouts.len,
                    .buffers = &vertex_layouts,
                },
                .primitive = wgpu.PrimitiveState{
                    .front_face = .ccw,
                    .cull_mode = .none,
                    .topology = topology,
                },
                .depth_stencil = &wgpu.DepthStencilState{
                    .format = .depth32_float,
                    .depth_write_enabled = true,
                    .depth_compare = .less,
                },
                .fragment = &wgpu.FragmentState{
                    .module = shader_source,
                    .entry_point = "fs",
                    .target_count = color_targets.len,
                    .targets = &color_targets,
                },
            };

            const pipeline = gctx.createRenderPipeline(pipeline_layout, pipeline_descriptor);

            return .{
                .pipeline = pipeline,
                .bind_group = bind_group,
            };
        }
    };
}
