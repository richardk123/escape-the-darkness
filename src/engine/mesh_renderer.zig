const std = @import("std");
const zgpu = @import("zgpu");
const zm = @import("zmath");

const Engine = @import("engine.zig").Engine;
const Material = @import("material.zig").Material;
const MaterialType = @import("material.zig").MaterialType;
const Vertex = @import("mesh.zig").Vertex;
const Mesh = @import("mesh.zig").Mesh;
const MeshType = @import("mesh.zig").MeshType;
const GPUBuffer = @import("common/buffer.zig").GPUBuffer;
const Constants = @import("./common//constants.zig");
const ModelTexture = @import("common/texture.zig").ModelTexture;

pub const MeshInstance = struct {
    position: [3]f32,
    rotation: [4]f32,
    scale: [3]f32,
    euler_angles: [3]f32 = .{ 0.0, 0.0, 0.0 }, // Roll, Pitch, Yaw
};

pub const MeshInstanceGPU = struct {
    model_matrix: zm.Mat,
};

pub const MeshRenderers = struct {
    allocator: std.mem.Allocator,
    mesh_renderers: std.ArrayList(MeshRenderer),

    pub fn init(allocator: std.mem.Allocator) !MeshRenderers {
        const mesh_instances = try std.ArrayList(MeshRenderer).initCapacity(allocator, Constants.INITIAL_MESH_INSTANCE_COUNT);
        return MeshRenderers{ .allocator = allocator, .mesh_renderers = mesh_instances };
    }

    pub fn add(self: *MeshRenderers, engine: *Engine, material_type: MaterialType, comptime mesh_type: MeshType) *MeshRenderer {
        const mi = MeshRenderer.init(engine, material_type, mesh_type) catch |err| {
            std.debug.panic("Failed to create mesh instance: {s}", .{@errorName(err)});
        };
        self.mesh_renderers.append(mi) catch |err| {
            std.debug.panic("Failed to add mesh instance: {s}", .{@errorName(err)});
        };
        return &self.mesh_renderers.items[self.mesh_renderers.items.len - 1];
    }

    pub fn writeBuffer(self: *MeshRenderers, buffer: *GPUBuffer(MeshInstanceGPU)) void {
        var mi_offset: usize = 0;
        for (self.mesh_renderers.items) |*mi| {
            mi.offset = mi_offset;
            mi_offset = mi_offset + mi.instances_gpu.items.len;
        }

        for (self.mesh_renderers.items) |mi| {
            buffer.writeWithOffset(mi.offset, mi.instances_gpu.items);
        }
    }

    pub fn deinit(self: *MeshRenderers) void {
        for (self.mesh_renderers.items) |*mi| {
            mi.deinit();
        }
        self.mesh_renderers.deinit();
    }
};

pub const MeshRenderer = struct {
    material: Material,
    normal_texture: ModelTexture,
    mesh_index: usize,
    instances: std.ArrayList(MeshInstance),
    instances_gpu: std.ArrayList(MeshInstanceGPU),
    instances_map: std.AutoHashMap(u32, *MeshInstance),
    // offset used for mesh_instance_buffer
    offset: usize = 0,
    id: u32 = 0,

    pub fn init(engine: *Engine, material_type: MaterialType, comptime mesh_type: MeshType) !MeshRenderer {
        const mesh_index = @as(usize, @intFromEnum(mesh_type));
        const normal_texture = try ModelTexture.init(&engine.renderer, engine.allocator, mesh_type.getNormalTextureName());
        const material = switch (material_type) {
            .echolocation => Material.init(engine, material_type, .triangle_list, &normal_texture),
            .wireframe => Material.init(engine, material_type, .line_list, null),
            .sound_texture => Material.init(engine, material_type, .triangle_list, null),
        };

        const instances = try std.ArrayList(MeshInstance).initCapacity(engine.allocator, Constants.MAX_INSTANCE_COUNT);
        const instances_gpu = try std.ArrayList(MeshInstanceGPU).initCapacity(engine.allocator, Constants.MAX_INSTANCE_COUNT);
        const instances_map = std.AutoHashMap(u32, *MeshInstance).init(engine.allocator);
        return MeshRenderer{
            .material = material,
            .mesh_index = mesh_index,
            .normal_texture = normal_texture,
            .instances = instances,
            .instances_gpu = instances_gpu,
            .instances_map = instances_map,
        };
    }

    pub fn addInstance(self: *MeshRenderer, position: ?[3]f32, rotation: ?[4]f32, scale: ?[3]f32) u32 {
        const instance: MeshInstance = .{
            .position = position orelse .{ 0.0, 0.0, 0.0 },
            .rotation = rotation orelse .{ 0.0, 0.0, 0.0, 1.0 },
            .scale = scale orelse .{ 1.0, 1.0, 1.0 },
        };
        self.instances.append(instance) catch |err| {
            std.debug.print("Failed to add instance: {}\n", .{err});
            @panic("cannot add instance");
        };

        // Create GPU instance with correct matrix
        const gpu_instance = createGPUInstance(instance);
        self.instances_gpu.append(gpu_instance) catch |err| {
            std.debug.print("Failed to add GPU instance: {}\n", .{err});
            @panic("cannot add gpu instance");
        };

        self.id += 1;

        self.instances_map.put(self.id, &self.instances.items[self.instances.items.len - 1]) catch |err| {
            std.debug.print("Failed to add instance pointer to map: {}\n", .{err});
            @panic("cannot add instance map");
        };

        return self.id;
    }

    pub fn updateInstance(self: *MeshRenderer, id: u32, position: ?[3]f32, rotation: ?[4]f32, scale: ?[3]f32) void {
        const instance = self.instances_map.get(id) orelse return;
        instance.position = position orelse instance.position;
        instance.rotation = rotation orelse instance.rotation;
        instance.scale = scale orelse instance.scale;
    }

    pub fn getInstance(self: *MeshRenderer, id: u32) ?*MeshInstance {
        return self.instances_map.get(id);
    }

    // Helper function to create a GPU instance from a CPU instance
    fn createGPUInstance(instance: MeshInstance) MeshInstanceGPU {
        const rotation_matrix = zm.matFromQuat(instance.rotation);
        const scale_matrix = zm.scaling(instance.scale[0], instance.scale[1], instance.scale[2]);
        const translation_matrix = zm.translation(instance.position[0], instance.position[1], instance.position[2]);
        const model_matrix = zm.mul(scale_matrix, zm.mul(rotation_matrix, translation_matrix));
        return MeshInstanceGPU{
            .model_matrix = model_matrix,
        };
    }

    // Function to update all GPU instances based on CPU instances
    pub fn updateAllGPUInstances(self: *MeshRenderer) void {
        // Clear GPU instances
        self.instances_gpu.clearRetainingCapacity();

        // Make sure we have enough capacity
        if (self.instances_gpu.capacity < self.instances.items.len) {
            self.instances_gpu.ensureTotalCapacity(self.instances.items.len) catch |err| {
                std.debug.print("Failed to ensure capacity for GPU instances: {}\n", .{err});
                return;
            };
        }

        // Update each GPU instance from its corresponding CPU instance
        for (self.instances.items) |instance| {
            const gpu_instance = createGPUInstance(instance);
            self.instances_gpu.append(gpu_instance) catch |err| {
                std.debug.print("Failed to append GPU instance: {}\n", .{err});
                return;
            };
        }
    }

    pub fn deinit(self: *MeshRenderer) void {
        self.instances.deinit();
        self.instances_gpu.deinit();
        self.instances_map.deinit();
    }
};
