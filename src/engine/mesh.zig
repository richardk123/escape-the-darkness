const std = @import("std");
const zmesh = @import("zmesh");
const expect = std.testing.expect;
const zgpu = @import("zgpu");
const ModelTexture = @import("common/texture.zig").ModelTexture;

// Enum of predefined sound files
pub const MeshType = enum {
    cube,
    monkey,
    plane,
    terrain,
    ship,
    flare,
    // Returns the file path for each sound
    pub fn getName(self: MeshType) [:0]const u8 {
        return switch (self) {
            .cube => "cube2",
            .monkey => "monkey",
            .plane => "plane",
            .terrain => "terrain",
            .ship => "space-ship",
            .flare => "flare",
        };
    }
    pub fn getNormalTextureName(self: MeshType) [:0]const u8 {
        return switch (self) {
            .cube => "stone_wall_normal.png",
            .monkey => "stone_wall_normal.png",
            .plane => "stone_wall_normal.png",
            .terrain => "stone_wall_normal.png",
            .ship => "stone_wall_normal.png",
            .flare => "stone_wall_normal.png",
        };
    }
};

pub const Vertex = extern struct {
    position: [3]f32 align(16),
    normal: [3]f32 align(16),
    uv: [2]f32 align(8),
    tangent: [4]f32 align(16),
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
        zmesh.init(allocator);

        var meshes = Meshes{
            .allocator = allocator,
            .meshes = std.ArrayList(Mesh).init(allocator),
            .vertices = std.ArrayList(Vertex).init(allocator),
            .indices = std.ArrayList(u32).init(allocator),
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
        var uv = std.ArrayList([2]f32).init(self.allocator);
        var tangents = std.ArrayList([4]f32).init(self.allocator);

        defer mesh_indices.deinit();
        defer mesh_positions.deinit();
        defer mesh_normals.deinit();
        defer uv.deinit();
        defer tangents.deinit();

        try zmesh.io.zcgltf.appendMeshPrimitive(
            data,
            0, // mesh index
            0, // gltf primitive index (submesh index)
            &mesh_indices,
            &mesh_positions,
            &mesh_normals, // normals (optional)
            &uv, // texcoords (optional)
            &tangents, // tangents (optional)
        );

        //TODO:
        if (std.mem.eql(u8, mesh_file, "cube2")) {
            std.debug.print("tangents: {any} \n", .{tangents.items});
            std.debug.print("normals: {any} \n", .{mesh_normals.items});
            std.debug.print("uv: {any} \n", .{uv.items});
        }
        const pre_indices_len = self.indices.items.len;
        const pre_vertices_len = self.vertices.items.len;

        // Add mesh array index data
        try self.meshes.append(.{
            .index_offset = @as(u32, @intCast(pre_indices_len)),
            .vertex_offset = @as(i32, @intCast(pre_vertices_len)),
            .num_indices = @as(u32, @intCast(mesh_indices.items.len)),
            .num_vertices = @as(u32, @intCast(mesh_positions.items.len)),
        });

        // Try with capacity reservation to avoid multiple allocations
        try self.vertices.ensureTotalCapacity(self.vertices.items.len + mesh_positions.items.len);
        for (mesh_positions.items, 0..) |_, index| {
            const vertex_uv = if (index < uv.items.len)
                uv.items[index]
            else
                .{ 0.0, 0.0 };

            const vertex_tangent = if (index < tangents.items.len)
                tangents.items[index]
            else
                .{ 1.0, 0.0, 0.0, 1.0 };

            const vertex_normal = if (index < mesh_normals.items.len)
                mesh_normals.items[index]
            else
                .{ 0.0, 1.0, 0.0 };

            try self.vertices.append(.{
                .position = mesh_positions.items[index],
                .normal = vertex_normal,
                .uv = vertex_uv,
                .tangent = vertex_tangent,
            });
        }

        // appe
        try self.indices.appendSlice(mesh_indices.items);
    }

    pub fn deinit(self: *Meshes) void {
        self.meshes.deinit();
        self.vertices.deinit();
        self.indices.deinit();
        zmesh.deinit();
    }
};
