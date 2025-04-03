const std = @import("std");
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;

const Renderer = @import("common/renderer.zig").Renderer;
const GPUBuffer = @import("common/buffer.zig").GPUBuffer;
const GPUTexture = @import("common/texture.zig").SoundsTexture;
const Material = @import("material.zig").Material;
const mesh = @import("mesh.zig");
const MeshInstances = @import("mesh_instance.zig").MeshInstances;
const MeshInstance = @import("mesh_instance.zig").MeshInstance;
const Instance = @import("mesh_instance.zig").Instance;
const Constants = @import("common/constants.zig");
const Camera = @import("camera.zig").Camera;
const sm = @import("sound/sound_manager.zig");
const Utils = @import("common/utils.zig");

pub const Engine = struct {
    allocator: std.mem.Allocator,
    window: *zglfw.Window,
    renderer: Renderer,
    meshes: *mesh.Meshes,
    mesh_instances: MeshInstances,
    vertex_buffer: GPUBuffer(mesh.Vertex),
    index_buffer: GPUBuffer(u32),
    instance_buffer: GPUBuffer(Instance),
    sounds_texture: GPUTexture,
    camera: Camera,
    sound_manager: sm.SoundManager,

    pub fn init(allocator: std.mem.Allocator, window: *zglfw.Window, meshes: *mesh.Meshes) !Engine {
        const renderer = try Renderer.init(allocator, window);
        const gctx = renderer.gctx;

        // Create a vertex buffer.
        const total_num_vertices = @as(u32, @intCast(meshes.vertices.items.len));
        const vertex_buffer = GPUBuffer(mesh.Vertex).init(gctx, .{ .copy_dst = true, .vertex = true }, total_num_vertices);
        vertex_buffer.write(meshes.vertices.items);

        // Create an index buffer.
        const total_num_indices = @as(u32, @intCast(meshes.indices.items.len));
        const index_buffer = GPUBuffer(u32).init(gctx, .{ .copy_dst = true, .index = true }, total_num_indices);
        index_buffer.write(meshes.indices.items);

        // Create an instances buffer
        const instances_buffer_usage: wgpu.BufferUsage = .{ .copy_dst = true, .storage = true };
        const instances_buffer = GPUBuffer(Instance).init(gctx, instances_buffer_usage, Constants.MAX_INSTANCE_COUNT);

        // Sound Manager
        const max_texture_size_2d = Utils.findTexture2dMaxSize(gctx);
        const sound_manager = try sm.SoundManager.init(allocator, max_texture_size_2d);

        // Create texture containing all sounds
        const sounds_data = sound_manager.data.sounds_texture_data.items;
        const sounds_texture = GPUTexture.init(gctx, sounds_data);

        // Create instances
        const mesh_instances = try MeshInstances.init(allocator);

        return Engine{
            .allocator = allocator,
            .window = window,
            .renderer = renderer,
            .meshes = meshes,
            .vertex_buffer = vertex_buffer,
            .index_buffer = index_buffer,
            .instance_buffer = instances_buffer,
            .mesh_instances = mesh_instances,
            .sounds_texture = sounds_texture,
            .camera = Camera.init(gctx),
            .sound_manager = sound_manager,
        };
    }

    pub fn addMeshInstance(self: *Engine, material: *const Material(mesh.Vertex), mesh_index: usize) *MeshInstance {
        return self.mesh_instances.add(material, mesh_index);
    }

    pub fn createMaterialDebug(self: *Engine, shader: [*:0]const u8) Material(mesh.Vertex) {
        return Material(mesh.Vertex).init(self, shader, .line_list);
    }

    pub fn createMaterial(self: *Engine, shader: [*:0]const u8) Material(mesh.Vertex) {
        return Material(mesh.Vertex).init(self, shader, .triangle_list);
    }

    pub fn update(self: *Engine) !void {
        self.sound_manager.update();
        try self.draw();
    }

    fn draw(self: *Engine) !void {
        const gctx = self.renderer.gctx;
        const pass = try self.renderer.createPass();
        defer {
            pass.end();
            pass.release();
        }

        // write camera buffer
        const camera_mem_offset = self.camera.writeBuffer();

        // write instance buffer
        self.mesh_instances.writeBuffer(&self.instance_buffer);

        // render each instance
        for (self.mesh_instances.mesh_instances.items) |mi| {
            pass: {
                const material = mi.material;
                const mesh_index = mi.mesh_index;
                const vb_info = gctx.lookupResourceInfo(self.vertex_buffer.gpu_buffer) orelse break :pass;
                const ib_info = gctx.lookupResourceInfo(self.index_buffer.gpu_buffer) orelse break :pass;
                const pipeline = gctx.lookupResource(material.pipeline) orelse break :pass;
                const bind_group = gctx.lookupResource(material.bind_group) orelse break :pass;

                pass.setVertexBuffer(0, vb_info.gpuobj.?, 0, vb_info.size);
                pass.setIndexBuffer(ib_info.gpuobj.?, .uint32, 0, ib_info.size);
                pass.setPipeline(pipeline);

                const instance_count = @as(u32, @intCast(mi.instances.items.len));
                pass.setBindGroup(0, bind_group, &.{camera_mem_offset});

                const instance_offset = @as(u32, @intCast(mi.offset));
                pass.drawIndexed(
                    self.meshes.meshes.items[mesh_index].num_indices,
                    instance_count,
                    self.meshes.meshes.items[mesh_index].index_offset,
                    self.meshes.meshes.items[mesh_index].vertex_offset,
                    instance_offset,
                );
            }
        }
    }

    pub fn deinit(self: *Engine) void {
        self.renderer.deinit();
        self.mesh_instances.deinit();
        self.sound_manager.deinit();
    }
};
