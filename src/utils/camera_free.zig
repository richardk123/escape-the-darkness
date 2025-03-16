const zglfw = @import("zglfw");
const math = @import("std").math;
const zm = @import("zmath");

const Camera = @import("../engine/camera.zig").Camera;
const Engine = @import("../engine/engine.zig").Engine;

pub const FreeCamera = struct {
    engine: *Engine,
    cursor_pos: [2]f64 = .{ 0, 0 },

    pub fn init(engine: *Engine) FreeCamera {
        return FreeCamera{
            .engine = engine,
        };
    }

    pub fn update(self: *FreeCamera) void {
        const window = self.engine.window;
        const gctx = self.engine.renderer.gctx;
        var camera = &self.engine.camera;

        // Handle camera rotation with mouse.
        {
            const cursor_pos = window.getCursorPos();
            const delta_x = @as(f32, @floatCast(cursor_pos[0] - self.cursor_pos[0]));
            const delta_y = @as(f32, @floatCast(cursor_pos[1] - self.cursor_pos[1]));
            self.cursor_pos = cursor_pos;

            if (window.getMouseButton(.right) == .press) {
                camera.pitch += 0.0025 * delta_y;
                camera.yaw += 0.0025 * delta_x;
                camera.pitch = @min(camera.pitch, 0.48 * math.pi);
                camera.pitch = @max(camera.pitch, -0.48 * math.pi);
                camera.yaw = zm.modAngle(camera.yaw);
            }
        }

        // Handle camera movement with 'WASD' keys.
        {
            const speed = zm.f32x4s(20.0);
            const delta_time = zm.f32x4s(gctx.stats.delta_time);
            const transform = zm.mul(zm.rotationX(camera.pitch), zm.rotationY(camera.yaw));
            var forward = zm.normalize3(zm.mul(zm.f32x4(0.0, 0.0, 1.0, 0.0), transform));

            zm.storeArr3(&camera.forward, forward);

            const right = speed * delta_time *
                zm.normalize3(zm.cross3(zm.f32x4(0.0, 1.0, 0.0, 0.0), forward));
            forward = speed * delta_time * forward;

            var cam_pos = zm.loadArr3(camera.position);

            if (window.getKey(.w) == .press) {
                cam_pos += forward;
            } else if (window.getKey(.s) == .press) {
                cam_pos -= forward;
            }
            if (window.getKey(.d) == .press) {
                cam_pos += right;
            } else if (window.getKey(.a) == .press) {
                cam_pos -= right;
            }

            zm.storeArr3(&camera.position, cam_pos);
        }
    }
};
