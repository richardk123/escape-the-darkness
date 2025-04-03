const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const Constants = @import("constants.zig");

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
