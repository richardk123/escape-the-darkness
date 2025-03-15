const std = @import("std");
const zgpu = @import("zgpu");
const zm = @import("zmath");
const math = std.math;

pub fn calculateCamera(gctx: *zgpu.GraphicsContext) u32 {
    const fb_width = gctx.swapchain_descriptor.width;
    const fb_height = gctx.swapchain_descriptor.height;

    // Create camera matrices
    const cam_world_to_view = zm.lookAtLh(
        zm.f32x4(0.0, 4.0, 40.0, 1.0), // eye position
        zm.f32x4(0.0, 0.0, 0.0, 1.0), // focus point
        zm.f32x4(0.0, 1.0, 0.0, 0.0), // up direction
    );

    const cam_view_to_clip = zm.perspectiveFovLh(
        0.25 * math.pi,
        @as(f32, @floatFromInt(fb_width)) / @as(f32, @floatFromInt(fb_height)),
        0.01,
        200.0,
    );

    // Combine view and projection matrices
    const world_to_clip = zm.mul(cam_world_to_view, cam_view_to_clip);

    // Just pass the world-to-clip matrix to the shader
    // Let the instances handle their own transformations
    const mem = gctx.uniformsAllocate(zm.Mat, 1);
    mem.slice[0] = zm.transpose(world_to_clip);

    return mem.offset;
}
