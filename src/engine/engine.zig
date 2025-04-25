const std = @import("std");
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zstbi = @import("zstbi");

const Renderer = @import("common/renderer.zig").Renderer;
const GPUBuffer = @import("common/buffer.zig").GPUBuffer;
const SoundTexture = @import("common/texture.zig").SoundsTexture;
const Material = @import("material.zig").Material;
const MaterialType = @import("material.zig").MaterialType;
const mesh = @import("mesh.zig");
const MeshRenderers = @import("mesh_renderer.zig").MeshRenderers;
const MeshRenderer = @import("mesh_renderer.zig").MeshRenderer;
const MeshInstanceGPU = @import("mesh_renderer.zig").MeshInstanceGPU;
const Constants = @import("common/constants.zig");
const Camera = @import("camera.zig").Camera;
const sm = @import("sound/sound_manager.zig");
const Utils = @import("common/utils.zig");
const GlobalUniform = @import("global_uniform.zig").GlobalUniform;
const ModelTexture = @import("common/texture.zig").ModelTexture;

pub const Engine = struct {
    allocator: std.mem.Allocator,
    window: *zglfw.Window,
    renderer: Renderer,
    meshes: mesh.Meshes,
    mesh_renderers: MeshRenderers,
    vertex_buffer: GPUBuffer(mesh.Vertex),
    instance_buffer: GPUBuffer(MeshInstanceGPU),
    sounds_texture: SoundTexture,
    camera: Camera,
    global_uniform: GlobalUniform,
    sound_manager: sm.SoundManager,

    pub fn init(allocator: std.mem.Allocator, window: *zglfw.Window) !Engine {
        // Lib for loading images
        zstbi.init(allocator);

        const renderer = try Renderer.init(allocator, window);
        const gctx = renderer.gctx;

        // Load all defined meshes
        const meshes = try mesh.Meshes.init(allocator);

        // Create vertex buffer.
        const total_num_vertices = @as(u32, @intCast(meshes.vertices.items.len));
        const vertex_buffer = GPUBuffer(mesh.Vertex).init(gctx, .{ .copy_dst = true, .vertex = true }, total_num_vertices);
        vertex_buffer.write(meshes.vertices.items);

        // Create instances buffer
        const instances_buffer_usage: wgpu.BufferUsage = .{ .copy_dst = true, .storage = true };
        const instances_buffer = GPUBuffer(MeshInstanceGPU).init(gctx, instances_buffer_usage, Constants.MAX_INSTANCE_COUNT);

        // Sound Manager
        const max_texture_size_2d = Utils.findTexture2dMaxSize(gctx);
        const sound_manager = try sm.SoundManager.init(allocator, max_texture_size_2d);

        // Create texture containing all sounds
        const sounds_data = sound_manager.data.sounds_texture_data.items;
        const sounds_texture = SoundTexture.init(gctx, sounds_data);

        // Create instances
        const mesh_renderers = try MeshRenderers.init(allocator);

        return Engine{
            .allocator = allocator,
            .window = window,
            .renderer = renderer,
            .meshes = meshes,
            .vertex_buffer = vertex_buffer,
            .instance_buffer = instances_buffer,
            .mesh_renderers = mesh_renderers,
            .sounds_texture = sounds_texture,
            .global_uniform = GlobalUniform.init(),
            .camera = Camera.init(gctx),
            .sound_manager = sound_manager,
        };
    }

    pub fn addMeshRenderer(self: *Engine, material_type: MaterialType, comptime mesh_type: mesh.MeshType) !*MeshRenderer {
        return self.mesh_renderers.add(self, material_type, mesh_type);
    }

    pub fn update(self: *Engine) !void {
        const gctx = self.renderer.gctx;
        self.sound_manager.update(&self.camera, gctx.stats.delta_time);
        try self.draw();
    }

    fn draw(self: *Engine) !void {
        const gctx = self.renderer.gctx;
        const pass = try self.renderer.createPass();
        defer {
            pass.end();
            pass.release();
        }

        // write global uniform data
        self.global_uniform.update(&self.camera, &self.sound_manager);

        const uniform_mem = gctx.uniformsAllocate(GlobalUniform, 1);
        uniform_mem.slice[0] = self.global_uniform;

        for (self.mesh_renderers.mesh_renderers.items) |*mi| {
            // update model matrices
            mi.updateAllGPUInstances();
        }

        // write instance buffer
        self.mesh_renderers.writeBuffer(&self.instance_buffer);

        // render each instance
        for (self.mesh_renderers.mesh_renderers.items) |mi| {
            pass: {
                const material = mi.material;
                const mesh_index = mi.mesh_index;
                const vb_info = gctx.lookupResourceInfo(self.vertex_buffer.gpu_buffer) orelse break :pass;
                const pipeline = gctx.lookupResource(material.pipeline) orelse break :pass;
                const bind_group = gctx.lookupResource(material.bind_group) orelse break :pass;

                pass.setVertexBuffer(0, vb_info.gpuobj.?, 0, vb_info.size);
                pass.setPipeline(pipeline);

                const instance_count = @as(u32, @intCast(mi.instances.items.len));
                pass.setBindGroup(0, bind_group, &.{uniform_mem.offset});

                const instance_offset = @as(u32, @intCast(mi.offset));
                pass.draw(
                    self.meshes.meshes.items[mesh_index].num_vertices,
                    instance_count,
                    self.meshes.meshes.items[mesh_index].vertex_offset,
                    instance_offset,
                );
            }
        }
    }

    pub fn deinit(self: *Engine) void {
        self.renderer.deinit();
        self.meshes.deinit();
        self.mesh_renderers.deinit();
        self.sound_manager.deinit();
        zstbi.deinit();
    }
};
