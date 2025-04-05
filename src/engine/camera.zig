const std = @import("std");
const zgpu = @import("zgpu");
const zm = @import("zmath");
const math = std.math;

pub const Camera = struct {
    gctx: *zgpu.GraphicsContext,

    position: [3]f32 = .{ 0, 2.0, 0.0 },
    forward: [3]f32 = .{ 0, 0, 1.0 },
    pitch: f32 = 0.0,
    yaw: f32 = math.pi,

    pub fn init(gctx: *zgpu.GraphicsContext) Camera {
        return Camera{ .gctx = gctx };
    }

    pub fn calculateCameraMatrix(self: *Camera) zm.Mat {
        const gctx = self.gctx;
        const fb_width = gctx.swapchain_descriptor.width;
        const fb_height = gctx.swapchain_descriptor.height;

        const cam_world_to_view = zm.lookToLh(
            zm.loadArr3(self.position),
            zm.loadArr3(self.forward),
            zm.f32x4(0.0, 1.0, 0.0, 0.0),
        );

        const cam_view_to_clip = zm.perspectiveFovLh(
            0.25 * math.pi,
            @as(f32, @floatFromInt(fb_width)) / @as(f32, @floatFromInt(fb_height)),
            0.01,
            3000.0,
        );

        const cam_world_to_clip = zm.mul(cam_world_to_view, cam_view_to_clip);

        return zm.transpose(cam_world_to_clip);
    }
};
