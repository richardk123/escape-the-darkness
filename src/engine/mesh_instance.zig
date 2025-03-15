const std = @import("std");
const Material = @import("material.zig").Material;
const Vertex = @import("mesh.zig").Vertex;
const GPUBuffer = @import("common/buffer.zig").GPUBuffer;
const zgpu = @import("zgpu");

pub const DEFAULT_INSTANCE_COUNT: usize = 500;

pub const Instance = struct {
    position: [3]f32,
    rotation: [4]f32,
    scale: [3]f32,
};

pub const MeshInstance = struct {
    material: *const Material(Vertex),
    mesh_index: usize,
    instances: std.ArrayList(Instance),
    buffer: GPUBuffer(Instance),

    pub fn init(allocator: std.mem.Allocator, gctx: *zgpu.GraphicsContext, material: *const Material(Vertex), mesh_index: usize) !MeshInstance {
        const instances = try std.ArrayList(Instance).initCapacity(allocator, DEFAULT_INSTANCE_COUNT);
        const buffer = GPUBuffer(Instance).init(gctx, .{ .copy_dst = true, .vertex = true, .storage = true }, DEFAULT_INSTANCE_COUNT);
        return MeshInstance{ .material = material, .mesh_index = mesh_index, .instances = instances, .buffer = buffer };
    }

    pub fn addInstance(self: *MeshInstance, instance: Instance) void {
        self.instances.appendAssumeCapacity(instance);
    }

    pub fn write(self: *MeshInstance) void {
        self.buffer.write(self.instances.items);
    }

    pub fn deinit(self: *const MeshInstance) void {
        self.instances.deinit();
    }
};
