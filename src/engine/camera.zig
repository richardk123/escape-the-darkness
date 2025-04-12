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

    pub fn world_to_clip(self: *Camera) zm.Mat {
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

    pub fn object_to_world(self: *Camera) zm.Mat {
        // Create translation matrix from camera position
        const translation = zm.translation(self.position[0], self.position[1], self.position[2]);

        // Create rotation matrices from camera pitch and yaw
        const rot_x = zm.rotationX(self.pitch); // pitch rotation
        const rot_y = zm.rotationY(self.yaw); // yaw rotation

        // Combine rotations (yaw then pitch)
        const rotation_mat = zm.mul(rot_y, rot_x);

        // We typically use a scale of 1 for the camera
        const scaling = zm.scaling(1.0, 1.0, 1.0);

        // Combine transformations
        const transform = zm.mul(zm.mul(scaling, rotation_mat), translation);

        return transform;
    }
};
