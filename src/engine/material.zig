const std = @import("std");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const GPUBuffer = @import("common/buffer.zig").GPUBuffer;
const GPULayout = @import("common/layout.zig").GPULayout;
const MeshInstance = @import("mesh_renderer.zig").MeshInstance;
const Engine = @import("engine.zig").Engine;
const GlobalUniform = @import("global_uniform.zig").GlobalUniform;
const ModelTexture = @import("common/texture.zig").ModelTexture;

const echolocation_shader = @embedFile("shader/echolocation.wgsl");
const debug_shader = @embedFile("shader/debug.wgsl");
const debug_sound_texture_shader = @embedFile("shader/debug_sound_texture.wgsl");

pub const MaterialType = enum {
    echolocation,
    wireframe,
    sound_texture,

    pub fn getShaderCode(self: MaterialType) [:0]const u8 {
        return switch (self) {
            .echolocation => echolocation_shader,
            .wireframe => debug_shader,
            .sound_texture => debug_sound_texture_shader,
        };
    }
};

pub fn Material(comptime T: type) type {
    return struct {
        pipeline: zgpu.RenderPipelineHandle,
        bind_group: zgpu.BindGroupHandle,

        const Self = @This();

        pub fn init(
            engine: *Engine,
            material_type: MaterialType,
            topology: wgpu.PrimitiveTopology,
            normal_texture: ?*const ModelTexture,
        ) Self {
            const gctx = engine.renderer.gctx;
            const instance_buffer = engine.instance_buffer;
            const sounds_texture = engine.sounds_texture;

            // Create a bind group layout needed for our render pipeline.
            const bind_group_layout = if (normal_texture != null)
                gctx.createBindGroupLayout(&.{
                    zgpu.bufferEntry(0, .{ .vertex = true, .fragment = true }, .uniform, true, 0),
                    zgpu.bufferEntry(1, .{ .vertex = true }, .read_only_storage, false, 0),
                    zgpu.textureEntry(2, .{ .vertex = true, .fragment = true }, .float, .tvdim_2d, false),
                    zgpu.samplerEntry(3, .{ .vertex = true, .fragment = true }, .non_filtering),
                    zgpu.textureEntry(4, .{ .fragment = true }, .float, .tvdim_2d, false),
                    zgpu.samplerEntry(5, .{ .fragment = true }, .filtering),
                })
            else
                gctx.createBindGroupLayout(&.{
                    zgpu.bufferEntry(0, .{ .vertex = true, .fragment = true }, .uniform, true, 0),
                    zgpu.bufferEntry(1, .{ .vertex = true }, .read_only_storage, false, 0),
                    zgpu.textureEntry(2, .{ .vertex = true, .fragment = true }, .float, .tvdim_2d, false),
                    zgpu.samplerEntry(3, .{ .vertex = true, .fragment = true }, .non_filtering),
                });
            defer gctx.releaseResource(bind_group_layout);

            const bind_group = if (normal_texture != null)
                gctx.createBindGroup(bind_group_layout, &.{
                    .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = @sizeOf(GlobalUniform) },
                    .{ .binding = 1, .buffer_handle = instance_buffer.gpu_buffer, .offset = 0, .size = (@sizeOf(MeshInstance) * instance_buffer.total_number) },
                    .{ .binding = 2, .texture_view_handle = sounds_texture.texture_view },
                    .{ .binding = 3, .sampler_handle = sounds_texture.sampler },
                    .{ .binding = 4, .texture_view_handle = normal_texture.?.texture_view },
                    .{ .binding = 5, .sampler_handle = normal_texture.?.sampler },
                })
            else
                gctx.createBindGroup(bind_group_layout, &.{
                    .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = @sizeOf(GlobalUniform) },
                    .{ .binding = 1, .buffer_handle = instance_buffer.gpu_buffer, .offset = 0, .size = (@sizeOf(MeshInstance) * instance_buffer.total_number) },
                    .{ .binding = 2, .texture_view_handle = sounds_texture.texture_view },
                    .{ .binding = 3, .sampler_handle = sounds_texture.sampler },
                });

            const pipeline_layout = gctx.createPipelineLayout(&.{bind_group_layout});
            defer gctx.releaseResource(pipeline_layout);

            const shader_source = zgpu.createWgslShaderModule(gctx.device, material_type.getShaderCode(), "shader_source");
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
