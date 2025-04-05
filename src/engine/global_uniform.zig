const std = @import("std");
const zm = @import("zmath");
const Constants = @import("common/constants.zig");
const sm = @import("sound/sound_manager.zig");
const Camera = @import("camera.zig").Camera;

pub const GlobalUniform = extern struct {
    // Camera matrix
    camera_matrix: zm.Mat, // 16 * 4 = 64 bytes
    camera_position: [3]f32,
    // Sound data
    sound_count: u32,
    // Array of sound instances
    sound_instances: [Constants.MAX_SOUND_COUNT]sm.SoundInstanceData,

    pub fn init() GlobalUniform {
        var uniform = GlobalUniform{
            .camera_matrix = zm.identity(),
            .camera_position = .{ 0.0, 0.0, 0.0 },
            .sound_count = 0,
            .sound_instances = undefined,
        };

        // Initialize all sound instances
        for (&uniform.sound_instances) |*instance| {
            instance.* = .{
                .offset = 0,
                .size = 0,
                .current_frame = 0,
                .position = .{ 0.0, 0.0, 0.0 },
                ._padding1 = 0,
                ._padding2 = 0,
            };
        }

        return uniform;
    }

    pub fn update(self: *GlobalUniform, camera: *Camera, sound_manager: *sm.SoundManager) void {
        // Update camera matrix
        self.camera_matrix = camera.calculateCameraMatrix();
        self.camera_position = camera.position;
        // Update sound count
        self.sound_count = sound_manager.uniform.count;

        // Update sound instances
        for (0..Constants.MAX_SOUND_COUNT) |i| {
            if (i < sound_manager.uniform.count) {
                self.sound_instances[i] = sound_manager.uniform.instances[i];
            } else {
                self.sound_instances[i] = .{
                    .offset = 0,
                    .size = 0,
                    .current_frame = 0,
                    .position = .{ 0.0, 0.0, 0.0 },
                    ._padding1 = 0,
                    ._padding2 = 0,
                };
            }
        }
    }
};

// Verify the alignment
comptime {
    if (@sizeOf(GlobalUniform) % 16 != 0) {
        @compileError("GlobalUniform must be 16-byte aligned for WebGPU. Current size: " ++ std.fmt.comptimePrint("{}", .{@sizeOf(GlobalUniform)}));
    }
}
