const std = @import("std");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;

pub fn GPULayout(comptime T: type) type {
    return struct {
        const Self = @This();

        pub fn createVertexBufferLayouts() [1]wgpu.VertexBufferLayout {
            const field_names = comptime blk: {
                const fields = std.meta.fields(T);
                var names: [fields.len][]const u8 = undefined;
                for (fields, 0..) |field, i| {
                    names[i] = field.name;
                }
                break :blk &names;
            };

            const vertex_attributes = comptime blk: {
                var attrs: [field_names.len]wgpu.VertexAttribute = undefined;
                for (field_names, 0..) |field, i| {
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
