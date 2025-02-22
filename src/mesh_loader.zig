const zmesh = @import("zmesh");
const std = @import("std");
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
        zmesh.init(allocator);
        defer zmesh.deinit();

        const data = try zmesh.io.zcgltf.parseAndLoadFile("content/" ++ "cube.gltf");
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

        std.debug.print(" \n \nindices {any} \n \n", .{mesh_indices.items});
        std.debug.print(" \n \npositions {any} \n \n", .{mesh_positions.items});
        std.debug.print(" \n \nnormals {any} \n \n", .{mesh_normals.items});

        var meshes = std.ArrayList(Mesh).init(allocator);
        var vertices = std.ArrayList(Vertex).init(allocator);
        var indices = std.ArrayList(u32).init(allocator);

        try meshes.append(.{
            .index_offset = 0,
            .vertex_offset = 0,
            .num_indices = @as(u32, @intCast(indices.items.len)),
            .num_vertices = @as(u32, @intCast(mesh_positions.items.len)),
        });

        try vertices.ensureTotalCapacity(mesh_positions.items.len);
        for (mesh_positions.items, 0..) |_, index| {
            vertices.appendAssumeCapacity(.{
                .position = mesh_positions.items[index],
                .normal = mesh_normals.items[index],
            });
        }

        try indices.ensureTotalCapacity(mesh_indices.items.len);
        for (mesh_indices.items) |mesh_index| {
            indices.appendAssumeCapacity(mesh_index);
        }

        return Meshes{
            .meshes = meshes,
            .vertices = vertices,
            .indices = indices,
        };
    }

    pub fn deinit(self: *Meshes) void {
        self.meshes.deinit();
        self.vertices.deinit();
        self.indices.deinit();
    }
};
