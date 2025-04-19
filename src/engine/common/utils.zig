const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zm = @import("zmath");
const Constants = @import("constants.zig");
const std = @import("std");

pub fn findTexture2dMaxSize(gctx: *zgpu.GraphicsContext) u32 {
    var limits: wgpu.SupportedLimits = .{};
    const limits_success = gctx.device.getLimits(&limits);

    // Default to 8192 if getting limits fails
    const max_texture_size: u32 = if (limits_success)
        limits.limits.max_texture_dimension_2d
    else
        Constants.MAX_TEXTURE_SIZE_FALLBACK;

    return max_texture_size;
}

pub fn distance(p1: [3]f32, p2: [3]f32) f32 {
    const dx = p2[0] - p1[0];
    const dy = p2[1] - p1[1];
    const dz = p2[2] - p1[2];

    return std.math.sqrt(dx * dx + dy * dy + dz * dz);
}
