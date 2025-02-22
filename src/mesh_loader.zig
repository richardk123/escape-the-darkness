const zmesh = @import("zmesh");
const std = @import("std");
const expect = std.testing.expect;

pub fn loadMeshes(allocator: std.mem.Allocator) !void {
    var arena_state = std.heap.ArenaAllocator.init(allocator);
    defer arena_state.deinit();
    const arena = arena_state.allocator();

    zmesh.init(arena);
    defer zmesh.deinit();

    const data = try zmesh.io.zcgltf.parseAndLoadFile("content/" ++ "cube.gltf");
    defer zmesh.io.zcgltf.freeData(data);

    var mesh_indices = std.ArrayList(u32).init(arena);
    var mesh_positions = std.ArrayList([3]f32).init(arena);
    var mesh_normals = std.ArrayList([3]f32).init(arena);

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

    std.debug.print("indices {}", .{mesh_indices});
    std.debug.print("positions {}", .{mesh_positions});
    std.debug.print("normals {}", .{mesh_normals});
}
