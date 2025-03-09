const std = @import("std");
const zmesh = @import("zmesh");
const expect = std.testing.expect;

pub const Vertex = extern struct {
    position: [3]f32,
    normal: [3]f32,
};

pub const Mesh = struct {
    index_offset: u32,
    vertex_offset: i32,
    num_indices: u32,
    num_vertices: u32,
};

pub const Meshes = struct {
    meshes: std.ArrayList(Mesh),
    vertices: std.ArrayList(Vertex),
    indices: std.ArrayList(u32),

    pub fn init(allocator: std.mem.Allocator) !Meshes {
        return Meshes{
            .meshes = std.ArrayList(Mesh).init(allocator),
            .vertices = std.ArrayList(Vertex).init(allocator),
            .indices = std.ArrayList(u32).init(allocator),
        };
    }

    pub fn loadMesh(self: *Meshes, allocator: std.mem.Allocator, comptime mesh_file: [:0]const u8) !usize {
        zmesh.init(allocator);
        defer zmesh.deinit();

        const data = try zmesh.io.zcgltf.parseAndLoadFile("content/" ++ mesh_file);
        defer zmesh.io.zcgltf.freeData(data);

        var mesh_indices = std.ArrayList(u32).init(allocator);
        var mesh_positions = std.ArrayList([3]f32).init(allocator);
        var mesh_normals = std.ArrayList([3]f32).init(allocator);
        defer mesh_indices.deinit();
        defer mesh_positions.deinit();
        defer mesh_normals.deinit();

        try zmesh.io.zcgltf.appendMeshPrimitive(
            data,
            0, // mesh index
            0, // gltf primitive index (submesh index)
            &mesh_indices,
            &mesh_positions,
            &mesh_normals, // normals (optional)
            null, // texcoords (optional)
            null, // tangents (optional)
        );

        const pre_indices_len = self.indices.items.len;
        const pre_vertices_len = self.vertices.items.len;

        try self.meshes.append(.{
            .index_offset = @as(u32, @intCast(pre_indices_len)),
            .vertex_offset = @as(i32, @intCast(pre_vertices_len)),
            .num_indices = @as(u32, @intCast(mesh_indices.items.len)),
            .num_vertices = @as(u32, @intCast(mesh_positions.items.len)),
        });

        try self.vertices.ensureTotalCapacity(mesh_positions.items.len);
        for (mesh_positions.items, 0..) |_, index| {
            self.vertices.appendAssumeCapacity(.{
                .position = mesh_positions.items[index],
                .normal = mesh_normals.items[index],
            });
        }

        try self.indices.ensureTotalCapacity(mesh_indices.items.len);
        for (mesh_indices.items) |mesh_index| {
            self.indices.appendAssumeCapacity(mesh_index);
        }
        return self.meshes.items.len;
    }

    pub fn deinit(self: *Meshes) void {
        self.meshes.deinit();
        self.vertices.deinit();
        self.indices.deinit();
    }
};
