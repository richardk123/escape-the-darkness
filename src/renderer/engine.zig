const std = @import("std");
const Meshes = @import("mesh_loader.zig").Meshes;

export const Engine = struct {
    allocator: std.mem.Allocator,
    meshes: Meshes,

    pub fn init(allocator: std.mem.Allocator) !Engine {
        return Engine{
            .allocator = allocator,
            .meshes = Meshes.init(allocator),
        };
    }

    pub fn loadMesh(self: *Engine, comptime mesh_file: [:0]const u8) !usize {
        return self.meshes.loadMesh(self.allocator, mesh_file);
    }
};
