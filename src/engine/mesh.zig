const std = @import("std");
const zmesh = @import("zmesh");
const expect = std.testing.expect;

pub const Vertex = extern struct {
    position: [3]f32,
    normal: [3]f32,
    uv: [2]f32,
};

pub const Mesh = struct {
    index_offset: u32,
    vertex_offset: i32,
    num_indices: u32,
    num_vertices: u32,
};

pub const Meshes = struct {
    allocator: std.mem.Allocator,
    meshes: std.ArrayList(Mesh),
    vertices: std.ArrayList(Vertex),
    indices: std.ArrayList(u32),

    pub fn init(allocator: std.mem.Allocator) !Meshes {
        return Meshes{
            .allocator = allocator,
            .meshes = std.ArrayList(Mesh).init(allocator),
            .vertices = std.ArrayList(Vertex).init(allocator),
            .indices = std.ArrayList(u32).init(allocator),
        };
    }

    pub fn loadMesh(self: *Meshes, comptime mesh_file: [:0]const u8) !usize {
        zmesh.init(self.allocator);
        defer zmesh.deinit();

        const data = try zmesh.io.zcgltf.parseAndLoadFile("content/" ++ mesh_file);
        defer zmesh.io.zcgltf.freeData(data);

        var mesh_indices = std.ArrayList(u32).init(self.allocator);
        var mesh_positions = std.ArrayList([3]f32).init(self.allocator);
        var mesh_normals = std.ArrayList([3]f32).init(self.allocator);
        var uv = std.ArrayList([2]f32).init(self.allocator);
        defer mesh_indices.deinit();
        defer mesh_positions.deinit();
        defer mesh_normals.deinit();
        defer uv.deinit();

        try zmesh.io.zcgltf.appendMeshPrimitive(
            data,
            0, // mesh index
            0, // gltf primitive index (submesh index)
            &mesh_indices,
            &mesh_positions,
            &mesh_normals, // normals (optional)
            &uv, // texcoords (optional)
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
            const vertex_uv = if (index < uv.items.len)
                uv.items[index]
            else
                .{ 0.0, 0.0 };
            try self.vertices.append(.{
                .position = mesh_positions.items[index],
                .normal = mesh_normals.items[index],
                .uv = vertex_uv,
            });
        }

        try self.indices.ensureTotalCapacity(mesh_indices.items.len);
        for (mesh_indices.items) |mesh_index| {
            try self.indices.append(mesh_index);
        }
        return self.meshes.items.len - 1;
    }

    pub fn addGeneratedMesh(self: *Meshes, vertices_data: []const Vertex, indices_data: []const u32) !usize {
        const pre_indices_len = self.indices.items.len;
        const pre_vertices_len = self.vertices.items.len;

        const mesh: Mesh = .{
            .index_offset = @as(u32, @intCast(pre_indices_len)),
            .vertex_offset = @as(i32, @intCast(pre_vertices_len)),
            .num_indices = @as(u32, @intCast(indices_data.len)),
            .num_vertices = @as(u32, @intCast(vertices_data.len)),
        };
        // Create new mesh entry
        try self.meshes.append(mesh);

        // Add vertices
        try self.vertices.appendSlice(vertices_data);

        // Add indices
        try self.indices.appendSlice(indices_data);

        std.debug.print("dynamic mesh: num_vertices {} num_indices {} \n\n", .{ mesh.num_vertices, mesh.num_indices });

        // Return the index of the new mesh
        return self.meshes.items.len - 1;
    }

    pub fn deinit(self: *Meshes) void {
        self.meshes.deinit();
        self.vertices.deinit();
        self.indices.deinit();
    }
};
