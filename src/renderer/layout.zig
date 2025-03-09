const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;

pub fn GPULayout(comptime T: type) type {
    return struct {
        const Self = @This();

        pub fn createVertexBufferLayouts(comptime fields: []const []const u8) [1]wgpu.VertexBufferLayout {
            const vertex_attributes = comptime blk: {
                var attrs: [fields.len]wgpu.VertexAttribute = undefined;
                for (fields, 0..) |field, i| {
                    attrs[i] = .{
                        .format = .float32x3,
                        .offset = @offsetOf(T, field),
                        .shader_location = i,
                    };
                }
                break :blk attrs;
            };

            return [_]wgpu.VertexBufferLayout{.{
                .array_stride = @sizeOf(T),
                .attribute_count = vertex_attributes.len,
                .attributes = &vertex_attributes,
            }};
        }
    };
}
