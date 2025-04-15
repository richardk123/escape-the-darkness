const std = @import("std");
const Math = @import("std").math;
const zstbi = @import("zstbi");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const Utils = @import("utils.zig");
const Renderer = @import("renderer.zig").Renderer;

pub const SoundsTexture = struct {
    texture: zgpu.TextureHandle,
    texture_view: zgpu.TextureViewHandle,
    sampler: zgpu.SamplerHandle,
    gctx: *zgpu.GraphicsContext,
    max_texture_size: u32,

    // Sound data always align to max_texture_size
    pub fn init(gctx: *zgpu.GraphicsContext, sounds_data: []const u8) SoundsTexture {
        // Default to 8192 if getting limits fails
        const max_texture_size: u32 = Utils.findTexture2dMaxSize(gctx);

        // Calculate dimensions based on data size
        const total_pixels = sounds_data.len / 4;
        const width = max_texture_size;
        const height = @as(u32, @intCast((total_pixels + width - 1) / width)); // Ceiling division

        std.debug.print("sound texture: [{}, {}], data bytes: {}\n", .{ width, height, sounds_data.len });

        // Make sure we have enough data for the texture
        if (sounds_data.len != total_pixels * 4) {
            @panic("Insufficient data for texture of specified dimensions");
        }

        const texture = gctx.createTexture(.{
            .usage = .{ .texture_binding = true, .copy_dst = true },
            .size = .{
                .width = width,
                .height = height,
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
                .bytes_per_row = width * 4,
                .rows_per_image = height,
            },
            .{ .width = width, .height = height },
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
    //todo free texture
};

pub const ModelTexture = struct {
    texture: zgpu.TextureHandle,
    texture_view: zgpu.TextureViewHandle,
    sampler: zgpu.SamplerHandle,
    gctx: *zgpu.GraphicsContext,

    pub fn init(renderer: *Renderer, allocator: std.mem.Allocator, comptime texture_name: [:0]const u8) !ModelTexture {
        const gctx = renderer.gctx;
        const path = "content/textures/" ++ texture_name;
        std.debug.print("loading texture: {s}\n", .{path});
        var image = try zstbi.Image.loadFromFile(path, 4);
        defer image.deinit();

        const texture = gctx.createTexture(.{
            .usage = .{ .texture_binding = true, .copy_dst = true },
            .size = .{
                .width = image.width,
                .height = image.height,
                .depth_or_array_layers = 1,
            },
            .format = zgpu.imageInfoToTextureFormat(
                image.num_components,
                image.bytes_per_component,
                image.is_hdr,
            ),
            .mip_level_count = Math.log2_int(u32, @max(image.width, image.height)) + 1,
        });
        const texture_view = gctx.createTextureView(texture, .{});

        gctx.queue.writeTexture(
            .{ .texture = gctx.lookupResource(texture).? },
            .{
                .bytes_per_row = image.bytes_per_row,
                .rows_per_image = image.height,
            },
            .{ .width = image.width, .height = image.height },
            u8,
            image.data,
        );

        var arena_state = std.heap.ArenaAllocator.init(allocator);
        defer arena_state.deinit();
        const arena = arena_state.allocator();

        gctx.generateMipmaps(
            arena,
            renderer.encoder,
            texture,
        );

        const trilinear_sam = gctx.createSampler(.{
            .address_mode_u = .repeat, // This is crucial for tiling
            .address_mode_v = .repeat, // This is crucial for tiling
            .address_mode_w = .repeat,
            .mag_filter = .linear,
            .min_filter = .linear,
            .mipmap_filter = .linear,
        });

        return ModelTexture{
            .gctx = gctx,
            .texture = texture,
            .texture_view = texture_view,
            .sampler = trilinear_sam,
        };
    }
};
