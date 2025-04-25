const std = @import("std");
const zmesh = @import("zmesh");
const zgpu = @import("zgpu");
const ModelTexture = @import("common/texture.zig").ModelTexture;

// Enum of predefined mesh types
pub const MeshType = enum {
    cube,
    cube_long,
    floor,
    sphere,
    plane,

    // Returns the file name for each mesh
    pub fn getName(self: MeshType) [:0]const u8 {
        return switch (self) {
            .cube => "cube_2x2x2",
            .cube_long => "cube_2x2x6",
            .floor => "floor",
            .sphere => "sphere_2x2x2",
            .plane => "plane",
        };
    }

    pub fn getNormalTextureName(self: MeshType) [:0]const u8 {
        return switch (self) {
            .cube => "stone_wall_normal.png",
            .cube_long => "stone_wall_normal.png",
            .floor => "stone_wall_normal.png",
            .sphere => "stone_wall_normal.png",
            .plane => "stone_wall_normal.png",
        };
    }
};

pub const Vertex = struct {
    position: [3]f32 align(16),
    normal: [3]f32 align(16),
    uv: [2]f32 align(8),
    tangent: [4]f32 align(16),
    barycentric: [3]f32 align(16),
};

pub const Mesh = struct {
    vertex_offset: u32,
    num_vertices: u32,
};

pub const Meshes = struct {
    allocator: std.mem.Allocator,
    meshes: std.ArrayList(Mesh),
    vertices: std.ArrayList(Vertex),

    pub fn init(allocator: std.mem.Allocator) !Meshes {
        zmesh.init(allocator);

        var meshes = Meshes{
            .allocator = allocator,
            .meshes = std.ArrayList(Mesh).init(allocator),
            .vertices = std.ArrayList(Vertex).init(allocator),
        };

        inline for (comptime std.enums.values(MeshType)) |mesh_type| {
            try meshes.loadMesh(mesh_type.getName());
        }

        return meshes;
    }

    fn loadMesh(self: *Meshes, comptime mesh_file: [:0]const u8) !void {
        const data = try zmesh.io.zcgltf.parseAndLoadFile("content/models/" ++ mesh_file ++ ".gltf");
        defer zmesh.io.zcgltf.freeData(data);

        var mesh_indices = std.ArrayList(u32).init(self.allocator);
        var mesh_positions = std.ArrayList([3]f32).init(self.allocator);
        var mesh_normals = std.ArrayList([3]f32).init(self.allocator);
        var mesh_uvs = std.ArrayList([2]f32).init(self.allocator);
        var mesh_tangents = std.ArrayList([4]f32).init(self.allocator);

        defer mesh_indices.deinit();
        defer mesh_positions.deinit();
        defer mesh_normals.deinit();
        defer mesh_uvs.deinit();
        defer mesh_tangents.deinit();

        // Load mesh data from GLTF file
        try zmesh.io.zcgltf.appendMeshPrimitive(
            data,
            0, // mesh index
            0, // gltf primitive index (submesh index)
            &mesh_indices,
            &mesh_positions,
            &mesh_normals, // normals (optional)
            &mesh_uvs, // texcoords (optional)
            &mesh_tangents, // tangents (optional)
        );

        // Record the starting vertex index before adding new vertices
        const vertex_offset = @as(u32, @intCast(self.vertices.items.len));

        // Process indices as triangles (3 vertices per triangle)
        var i: usize = 0;
        while (i < mesh_indices.items.len) : (i += 3) {
            // Process one triangle at a time
            const idx1 = mesh_indices.items[i];
            const idx2 = mesh_indices.items[i + 1];
            const idx3 = mesh_indices.items[i + 2];

            // Add the three vertices of the triangle with correct barycentric coordinates
            try self.vertices.append(.{
                .position = mesh_positions.items[idx1],
                .normal = getOptionalAttribute(idx1, mesh_normals, .{ 0.0, 1.0, 0.0 }),
                .uv = getOptionalAttribute(idx1, mesh_uvs, .{ 0.0, 0.0 }),
                .tangent = getOptionalAttribute(idx1, mesh_tangents, .{ 1.0, 0.0, 0.0, 1.0 }),
                .barycentric = .{ 1.0, 0.0, 0.0 },
            });

            try self.vertices.append(.{
                .position = mesh_positions.items[idx2],
                .normal = getOptionalAttribute(idx2, mesh_normals, .{ 0.0, 1.0, 0.0 }),
                .uv = getOptionalAttribute(idx2, mesh_uvs, .{ 0.0, 0.0 }),
                .tangent = getOptionalAttribute(idx2, mesh_tangents, .{ 1.0, 0.0, 0.0, 1.0 }),
                .barycentric = .{ 0.0, 1.0, 0.0 },
            });

            try self.vertices.append(.{
                .position = mesh_positions.items[idx3],
                .normal = getOptionalAttribute(idx3, mesh_normals, .{ 0.0, 1.0, 0.0 }),
                .uv = getOptionalAttribute(idx3, mesh_uvs, .{ 0.0, 0.0 }),
                .tangent = getOptionalAttribute(idx3, mesh_tangents, .{ 1.0, 0.0, 0.0, 1.0 }),
                .barycentric = .{ 0.0, 0.0, 1.0 },
            });
        }

        // Add the mesh entry
        try self.meshes.append(.{
            .vertex_offset = vertex_offset,
            .num_vertices = @as(u32, @intCast(self.vertices.items.len - vertex_offset)),
        });
    }

    // Helper function to safely get an attribute from a list or return default
    fn getOptionalAttribute(index: u32, list: anytype, default: @TypeOf(list.items[0])) @TypeOf(list.items[0]) {
        if (index < list.items.len) {
            return list.items[index];
        }
        return default;
    }

    pub fn deinit(self: *Meshes) void {
        self.meshes.deinit();
        self.vertices.deinit();
        zmesh.deinit();
    }
};
