const std = @import("std");

const Vertex = @import("../renderer/mesh_loader.zig").Vertex;

pub const Grid = struct {
    vertices: std.ArrayList(Vertex),
    indices: std.ArrayList(u32),

    /// Creates a grid of size (size x size) centered at (0,0,0)
    /// size: Number of grid cells in each direction
    /// spacing: Distance between grid lines
    pub fn init(allocator: std.mem.Allocator, size: usize, spacing: f32) !Grid {
        var vertices = std.ArrayList(Vertex).init(allocator);
        var indices = std.ArrayList(u32).init(allocator);

        const line_count = size + 1;
        // 4 vertices per grid line (2 for X-axis line, 2 for Z-axis line)
        const vertex_count = line_count * 4;
        // 4 indices per grid line (2 for X-axis line, 2 for Z-axis line)
        const index_count = line_count * 4;

        try vertices.ensureTotalCapacity(vertex_count);
        try indices.ensureTotalCapacity(index_count);

        // Calculate the starting position to center the grid at (0,0,0)
        const half_grid_size = @as(f32, @floatFromInt(size)) * spacing / 2.0;

        for (0..line_count) |i| {
            const pos = @as(f32, @floatFromInt(i)) * spacing - half_grid_size;

            // Line along X-axis (from min to max X at current Z)
            vertices.appendAssumeCapacity(.{
                .position = [_]f32{ -half_grid_size, 0.0, pos },
                .normal = [_]f32{ 0.0, 1.0, 0.0 },
            });
            vertices.appendAssumeCapacity(.{
                .position = [_]f32{ half_grid_size, 0.0, pos },
                .normal = [_]f32{ 0.0, 1.0, 0.0 },
            });

            // Line along Z-axis (from min to max Z at current X)
            vertices.appendAssumeCapacity(.{
                .position = [_]f32{ pos, 0.0, -half_grid_size },
                .normal = [_]f32{ 0.0, 1.0, 0.0 },
            });
            vertices.appendAssumeCapacity(.{
                .position = [_]f32{ pos, 0.0, half_grid_size },
                .normal = [_]f32{ 0.0, 1.0, 0.0 },
            });

            // Indices for the two lines
            const base_idx = @as(u32, @intCast(i * 4));
            indices.appendAssumeCapacity(base_idx + 0);
            indices.appendAssumeCapacity(base_idx + 1);
            indices.appendAssumeCapacity(base_idx + 2);
            indices.appendAssumeCapacity(base_idx + 3);
        }

        return Grid{
            .vertices = vertices,
            .indices = indices,
        };
    }

    pub fn deinit(self: *const Grid) void {
        self.vertices.deinit();
        self.indices.deinit();
    }
};
