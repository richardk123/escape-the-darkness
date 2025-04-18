const std = @import("std");
const zgpu = @import("zgpu");
const zm = @import("zmath");
const math = std.math;

pub const Camera = struct {
    gctx: *zgpu.GraphicsContext,

    position: [3]f32 = .{ 0, 2.0, 0.0 },
    forward: [3]f32 = .{ 1.0, 0.0, 0.0 },
    pitch: f32 = 0.0,
    yaw: f32 = 0.0,

    pub fn init(gctx: *zgpu.GraphicsContext) Camera {
        return Camera{ .gctx = gctx };
    }

    // Returns the projection matrix (view space -> clip space)
    pub fn projection_matrix(self: *Camera) zm.Mat {
        const gctx = self.gctx;
        const fb_width = gctx.swapchain_descriptor.width;
        const fb_height = gctx.swapchain_descriptor.height;
        const aspect_ratio = @as(f32, @floatFromInt(fb_width)) / @as(f32, @floatFromInt(fb_height));

        const proj = zm.perspectiveFovLh(math.pi / @as(f32, 3.0), // fov
            aspect_ratio, 1.0, // near plane
            3000.0 // far plane
        );

        return proj;
    }

    // Returns the view matrix (world space -> view space)
    pub fn view_matrix(self: *Camera) zm.Mat {
        return zm.lookToLh(
            zm.loadArr3(self.position),
            zm.loadArr3(self.forward),
            zm.f32x4(0.0, 1.0, 0.0, 0.0),
        );
    }
};
