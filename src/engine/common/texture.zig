const std = @import("std");
const Math = @import("std").math;
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const Utils = @import("utils.zig");

pub const SoundsTexture = struct {
    texture: zgpu.TextureHandle,
    texture_view: zgpu.TextureViewHandle,
    sampler: zgpu.SamplerHandle,
    gctx: *zgpu.GraphicsContext,
    max_texture_size: u32,

    pub fn init(gctx: *zgpu.GraphicsContext, sounds_data: []const u8) SoundsTexture {
        // Default to 8192 if getting limits fails
        const max_texture_size: u32 = Utils.findTexture2dMaxSize(gctx);

        const pixel_data_len: u32 = @as(u32, @intCast(sounds_data.len)) / 4;
        const pixel_data_len_f32: f32 = @floatFromInt(pixel_data_len);
        const max_texture_size_f32: f32 = @floatFromInt(max_texture_size);

        // Verify dimensions don't exceed limits
        const width_fraction: u32 = @as(u32, @intFromFloat(pixel_data_len_f32 / max_texture_size_f32));
        const actual_height = Math.clamp(width_fraction, 1, max_texture_size);
        const actual_width = Math.clamp(pixel_data_len, 0, max_texture_size);
        std.debug.print("reminder: {} \n", .{pixel_data_len % max_texture_size});
        std.debug.print("pixel_data_len: {}, pixel_data_len_f32: {}, width_fraction: {}, max_texture_size_f32: {}\n", .{ pixel_data_len, pixel_data_len_f32, width_fraction, max_texture_size_f32 });

        // Make sure we have enough data for the texture
        const required_bytes = actual_width * actual_height * 4;
        std.debug.print("sound texture: [{}, {}], required bytes: {}, actual bytes: {}\n", .{ actual_width, actual_height, required_bytes, sounds_data.len });
        if (sounds_data.len < required_bytes) {
            // Handle error case - insufficient data
            @panic("Insufficient data for texture of specified dimensions");
        }

        const texture = gctx.createTexture(.{
            .usage = .{ .texture_binding = true, .copy_dst = true },
            .size = .{
                .width = actual_width,
                .height = actual_height,
                .depth_or_array_layers = 1,
            },
            .format = wgpu.TextureFormat.rgba8_unorm,
            .mip_level_count = 1,
        });
        const texture_view = gctx.createTextureView(texture, .{});

        // Create a sampler with CLAMP_TO_EDGE address mode
        const sampler = gctx.createSampler(.{
            .address_mode_u = .clamp_to_edge,
            .address_mode_v = .clamp_to_edge,
            .address_mode_w = .clamp_to_edge,
            .mag_filter = .nearest,
            .min_filter = .nearest,
            .mipmap_filter = .nearest,
        });

        gctx.queue.writeTexture(
            .{ .texture = gctx.lookupResource(texture).? },
            .{
                .bytes_per_row = actual_width * 4,
                .rows_per_image = actual_height,
            },
            .{ .width = actual_width, .height = actual_height },
            u8,
            sounds_data,
        );

        return SoundsTexture{
            .texture = texture,
            .texture_view = texture_view,
            .sampler = sampler,
            .gctx = gctx,
            .max_texture_size = max_texture_size,
        };
    }
};
