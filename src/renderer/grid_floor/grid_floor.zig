const std = @import("std");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zm = @import("zmath");
const math = std.math;

const RenderParams = @import("../gpu_engine.zig").RenderParams;

// Shaders
const vs_shader = @embedFile("vs.wgsl");
const fs_shader = @embedFile("fs.wgsl");

const Vertex = struct { position: [3]f32 };

pub const GridFloorProgram = struct {
    pipeline: zgpu.RenderPipelineHandle,
    bind_group: zgpu.BindGroupHandle,

    vertex_buffer: zgpu.BufferHandle,

    pub fn init(allocator: std.mem.Allocator, gctx: *zgpu.GraphicsContext) !GridFloorProgram {
        // Create a bind group layout needed for our render pipeline.
        const bind_group_layout = gctx.createBindGroupLayout(&.{
            zgpu.bufferEntry(0, .{ .vertex = true }, .uniform, true, 0),
        });
        defer gctx.releaseResource(bind_group_layout);

        const pipeline_layout = gctx.createPipelineLayout(&.{bind_group_layout});
        defer gctx.releaseResource(pipeline_layout);

        const pipeline = pipeline: {
            const vs_module = zgpu.createWgslShaderModule(gctx.device, vs_shader, "vs");
            defer vs_module.release();

            const fs_module = zgpu.createWgslShaderModule(gctx.device, fs_shader, "fs");
            defer fs_module.release();

            const color_targets = [_]wgpu.ColorTargetState{.{
                .format = zgpu.GraphicsContext.swapchain_format,
            }};

            const vertex_attributes = [_]wgpu.VertexAttribute{
                .{ .format = .float32x3, .offset = 0, .shader_location = 0 },
            };
            const vertex_buffers = [_]wgpu.VertexBufferLayout{.{
                .array_stride = @sizeOf(Vertex),
                .attribute_count = vertex_attributes.len,
                .attributes = &vertex_attributes,
            }};

            const pipeline_descriptor = wgpu.RenderPipelineDescriptor{
                .vertex = wgpu.VertexState{
                    .module = vs_module,
                    .entry_point = "main",
                    .buffer_count = vertex_buffers.len,
                    .buffers = &vertex_buffers,
                },
                .primitive = wgpu.PrimitiveState{
                    .front_face = .ccw,
                    .cull_mode = .none,
                    .topology = .line_list,
                },
                .depth_stencil = &wgpu.DepthStencilState{
                    .format = .depth32_float,
                    .depth_write_enabled = true,
                    .depth_compare = .less,
                },
                .fragment = &wgpu.FragmentState{
                    .module = fs_module,
                    .entry_point = "main",
                    .target_count = color_targets.len,
                    .targets = &color_targets,
                },
            };
            break :pipeline gctx.createRenderPipeline(pipeline_layout, pipeline_descriptor);
        };

        const bind_group = gctx.createBindGroup(bind_group_layout, &.{
            .{ .binding = 0, .buffer_handle = gctx.uniforms.buffer, .offset = 0, .size = @sizeOf(zm.Mat) },
        });

        var vertices = std.ArrayList(Vertex).init(allocator);
        try vertices.ensureTotalCapacity(400);

        for (0..100) |i| {
            vertices.appendAssumeCapacity(.{
                .position = [_]f32{ @floatFromInt(i), 0.0, 0.0 },
            });
            vertices.appendAssumeCapacity(.{
                .position = [_]f32{ @floatFromInt(i), 0.0, 99.0 },
            });
            vertices.appendAssumeCapacity(.{
                .position = [_]f32{ 0.0, 0.0, @floatFromInt(i) },
            });
            vertices.appendAssumeCapacity(.{
                .position = [_]f32{ 99.0, 0.0, @floatFromInt(i) },
            });
        }

        defer vertices.deinit();
        const total_num_vertices = @as(u32, @intCast(vertices.items.len));

        // Create a vertex buffer.
        const vertex_buffer = gctx.createBuffer(.{
            .usage = .{ .copy_dst = true, .vertex = true },
            .size = total_num_vertices * @sizeOf(Vertex),
        });
        gctx.queue.writeBuffer(gctx.lookupResource(vertex_buffer).?, 0, Vertex, vertices.items);

        return GridFloorProgram{
            .pipeline = pipeline,
            .bind_group = bind_group,
            .vertex_buffer = vertex_buffer,
        };
    }

    pub fn render(self: *GridFloorProgram, params: RenderParams) void {
        const gctx = params.gctx;

        const fb_width = gctx.swapchain_descriptor.width;
        const fb_height = gctx.swapchain_descriptor.height;

        const cam_world_to_view = zm.lookAtLh(
            zm.f32x4(3.0, 3.0, -3.0, 1.0), // eye position
            zm.f32x4(0.0, 0.0, 0.0, 1.0), // focus point
            zm.f32x4(0.0, 1.0, 0.0, 0.0), // up direction ('w' coord is zero because this is a vector not a point)
        );
        const cam_view_to_clip = zm.perspectiveFovLh(
            0.25 * math.pi,
            @as(f32, @floatFromInt(fb_width)) / @as(f32, @floatFromInt(fb_height)),
            0.01,
            200.0,
        );
        const cam_world_to_clip = zm.mul(cam_world_to_view, cam_view_to_clip);

        pass: {
            const vb_info = gctx.lookupResourceInfo(self.vertex_buffer) orelse break :pass;
            const pipeline = gctx.lookupResource(self.pipeline) orelse break :pass;
            const bind_group = gctx.lookupResource(self.bind_group) orelse break :pass;
            const depth_view = gctx.lookupResource(params.depth_texture_view) orelse break :pass;

            const color_attachments = [_]wgpu.RenderPassColorAttachment{.{
                .view = params.back_buffer_view,
                .load_op = .clear,
                .store_op = .store,
            }};
            const depth_attachment = wgpu.RenderPassDepthStencilAttachment{
                .view = depth_view,
                .depth_load_op = .clear,
                .depth_store_op = .store,
                .depth_clear_value = 1.0,
            };
            const render_pass_info = wgpu.RenderPassDescriptor{
                .color_attachment_count = color_attachments.len,
                .color_attachments = &color_attachments,
                .depth_stencil_attachment = &depth_attachment,
            };
            const pass = params.encoder.beginRenderPass(render_pass_info);
            defer {
                pass.end();
                pass.release();
            }

            pass.setVertexBuffer(0, vb_info.gpuobj.?, 0, vb_info.size);
            pass.setPipeline(pipeline);
            {
                const object_to_world = zm.identity();
                const object_to_clip = zm.mul(object_to_world, cam_world_to_clip);

                const mem = gctx.uniformsAllocate(zm.Mat, 1);
                mem.slice[0] = zm.transpose(object_to_clip);

                pass.setBindGroup(0, bind_group, &.{mem.offset});
                pass.draw(
                    400,
                    1,
                    0,
                    0,
                );
            }
        }
    }
};
