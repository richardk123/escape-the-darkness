const std = @import("std");
const zgpu = @import("zgpu");
const zm = @import("zmath");
const math = std.math;

pub fn calculateCamera(gctx: *zgpu.GraphicsContext) u32 {
    const fb_width = gctx.swapchain_descriptor.width;
    const fb_height = gctx.swapchain_descriptor.height;
    const t = @as(f32, @floatCast(gctx.stats.time)) / 2;

    const cam_world_to_view = zm.lookAtLh(
        zm.f32x4(0.0, 4.0, 9.0, 1.0), // eye position
        zm.f32x4(0.0, 0.0, 0.0, 1.0), // focus point
        zm.f32x4(0.0, 1.0, 0.0, 0.0), // up direction ('w' coord is zero because this is a vector not a point)
    );
    const cam_view_to_clip = zm.perspectiveFovLh(
        0.25 * math.pi,
        @as(f32, @floatFromInt(fb_width)) / @as(f32, @floatFromInt(fb_height)),
        0.01,
        200.0,
    );
    const cam_world_to_clip = zm.mul(cam_world_to_view, cam_view_to_clip);

    const object_to_world = zm.mul(zm.rotationY(t), zm.translation(-1.0, 0.0, 0.0));
    const object_to_clip = zm.mul(object_to_world, cam_world_to_clip);

    const mem = gctx.uniformsAllocate(zm.Mat, 1);
    mem.slice[0] = zm.transpose(object_to_clip);

    return mem.offset;
}
