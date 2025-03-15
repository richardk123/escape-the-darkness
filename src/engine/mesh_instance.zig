const std = @import("std");
const zgpu = @import("zgpu");

const Material = @import("material.zig").Material;
const Vertex = @import("mesh.zig").Vertex;
const GPUBuffer = @import("common/buffer.zig").GPUBuffer;
const Constants = @import("constants.zig");

pub const Instance = struct {
    position: [3]f32,
    _pad1: f32 = 0.0,
    rotation: [4]f32,
    scale: [3]f32,
    _pad2: f32 = 0.0,
};

pub const MeshInstances = struct {
    allocator: std.mem.Allocator,
    mesh_instances: std.ArrayList(MeshInstance),

    pub fn init(allocator: std.mem.Allocator) !MeshInstances {
        const mesh_instances = try std.ArrayList(MeshInstance).initCapacity(allocator, Constants.INITIAL_MESH_INSTANCE_COUNT);
        return MeshInstances{ .mesh_instances = mesh_instances, .allocator = allocator };
    }

    pub fn add(self: *MeshInstances, material: *const Material(Vertex), mesh_index: usize) !*MeshInstance {
        const mi = try MeshInstance.init(self.allocator, material, mesh_index);
        try self.mesh_instances.append(mi);
        return &self.mesh_instances.items[self.mesh_instances.items.len - 1];
    }

    pub fn writeBuffer(self: *MeshInstances, buffer: *GPUBuffer(Instance)) void {
        var mi_offset: usize = 0;
        for (self.mesh_instances.items) |*mi| {
            mi.offset = mi_offset;
            mi_offset = mi_offset + mi.instances.items.len;
        }

        for (self.mesh_instances.items) |mi| {
            buffer.writeWithOffset(mi.offset, mi.instances.items);
        }
    }

    pub fn deinit(self: *MeshInstances) void {
        for (self.mesh_instances.items) |mi| {
            mi.deinit();
        }
        self.mesh_instances.deinit();
    }
};

pub const MeshInstance = struct {
    material: *const Material(Vertex),
    mesh_index: usize,
    instances: std.ArrayList(Instance),
    // offset used for mesh_instance_buffer
    offset: usize = 0,

    pub fn init(allocator: std.mem.Allocator, material: *const Material(Vertex), mesh_index: usize) !MeshInstance {
        const instances = try std.ArrayList(Instance).initCapacity(allocator, Constants.MAX_INSTANCE_COUNT);
        return MeshInstance{ .material = material, .mesh_index = mesh_index, .instances = instances };
    }

    pub fn addInstance(self: *MeshInstance, instance: Instance) void {
        self.instances.appendAssumeCapacity(instance);
    }

    pub fn deinit(self: *const MeshInstance) void {
        self.instances.deinit();
    }
};
