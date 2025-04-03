const std = @import("std");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;

pub fn GPULayout(comptime T: type) type {
    return struct {
        const Self = @This();

        pub fn createVertexBufferLayouts() [1]wgpu.VertexBufferLayout {
            const fields = comptime std.meta.fields(T);

            const vertex_attributes = comptime blk: {
                var attrs: [fields.len]wgpu.VertexAttribute = undefined;
                for (fields, 0..) |field, i| {
                    const format = getVertexFormat(field);

                    attrs[i] = .{
                        .format = format,
                        .offset = @offsetOf(T, field.name),
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

        fn getVertexFormat(field: std.builtin.Type.StructField) wgpu.VertexFormat {
            const field_type: std.builtin.Type = @typeInfo(field.type);
            return switch (field_type) {
                .array => |array_info| {
                    if (array_info.child == f32) {
                        switch (array_info.len) {
                            2 => return wgpu.VertexFormat.float32x2,
                            3 => return wgpu.VertexFormat.float32x3,
                            else => @compileError("Unsupported array length for field: " ++ field.name),
                        }
                    } else {
                        @compileError("Unsupported array type for field: " ++ field.name);
                    }
                },
                else => @compileError("Unsupported field type for field: " ++ field.name),
            };
        }
    };
}
