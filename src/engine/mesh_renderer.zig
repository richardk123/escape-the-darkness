const std = @import("std");
const zgpu = @import("zgpu");

const Material = @import("material.zig").Material;
const Vertex = @import("mesh.zig").Vertex;
const GPUBuffer = @import("common/buffer.zig").GPUBuffer;
const Constants = @import("./common//constants.zig");

pub const MeshInstance = struct {
    position: [3]f32,
    _pad1: f32 = 0.0,
    rotation: [4]f32,
    scale: [3]f32,
    _pad2: f32 = 0.0,
};

pub const MeshRenderers = struct {
    allocator: std.mem.Allocator,
    mesh_renderers: std.ArrayList(MeshRenderer),

    pub fn init(allocator: std.mem.Allocator) !MeshRenderers {
        const mesh_instances = try std.ArrayList(MeshRenderer).initCapacity(allocator, Constants.INITIAL_MESH_INSTANCE_COUNT);
        return MeshRenderers{ .mesh_renderers = mesh_instances, .allocator = allocator };
    }

    pub fn add(self: *MeshRenderers, material: *const Material(Vertex), mesh_index: usize) *MeshRenderer {
        const mi = MeshRenderer.init(self.allocator, material, mesh_index) catch |err| {
            std.debug.panic("Failed to create mesh instance: {s}", .{@errorName(err)});
        };
        self.mesh_renderers.append(mi) catch |err| {
            std.debug.panic("Failed to add mesh instance: {s}", .{@errorName(err)});
        };
        return &self.mesh_renderers.items[self.mesh_renderers.items.len - 1];
    }

    pub fn writeBuffer(self: *MeshRenderers, buffer: *GPUBuffer(MeshInstance)) void {
        var mi_offset: usize = 0;
        for (self.mesh_renderers.items) |*mi| {
            mi.offset = mi_offset;
            mi_offset = mi_offset + mi.instances.items.len;
        }

        for (self.mesh_renderers.items) |mi| {
            buffer.writeWithOffset(mi.offset, mi.instances.items);
        }
    }

    pub fn deinit(self: *MeshRenderers) void {
        for (self.mesh_renderers.items) |mi| {
            mi.deinit();
        }
        self.mesh_renderers.deinit();
    }
};

pub const MeshRenderer = struct {
    material: *const Material(Vertex),
    mesh_index: usize,
    instances: std.ArrayList(MeshInstance),
    // offset used for mesh_instance_buffer
    offset: usize = 0,

    pub fn init(allocator: std.mem.Allocator, material: *const Material(Vertex), mesh_index: usize) !MeshRenderer {
        const instances = try std.ArrayList(MeshInstance).initCapacity(allocator, Constants.MAX_INSTANCE_COUNT);
        return MeshRenderer{ .material = material, .mesh_index = mesh_index, .instances = instances };
    }

    pub fn addInstance(self: *MeshRenderer, instance: MeshInstance) void {
        self.instances.append(instance) catch |err| {
            std.debug.print("Failed to add instance: {}\n", .{err});
            return;
        };
    }

    pub fn deinit(self: *const MeshRenderer) void {
        self.instances.deinit();
    }
};
