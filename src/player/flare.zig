const std = @import("std");
const zm = @import("zmath");

const Engine = @import("../engine/engine.zig").Engine;
const MeshRenderer = @import("../engine/mesh_renderer.zig").MeshRenderer;
const mat = @import("../engine/material.zig");
const mesh = @import("../engine/mesh.zig");
const sm = @import("../engine/sound/sound_manager.zig");
const Constants = @import("../engine/common/constants.zig");

const FLARE_COLOR: [3]f32 = .{ 0, 0, 0.6 };
const EXPLOSION_COLOR: [3]f32 = .{ 1, 1, 0 };

pub const Flares = struct {
    engine: *Engine,
    flares: std.ArrayList(Flare),
    flare_renderer: *MeshRenderer,
    cooldown_timer: f32 = 0.0, // Time until next flare can be shot
    cooldown_duration: f32 = 1.0, // 1 second cooldown between flares

    pub fn init(engine: *Engine) !Flares {
        return .{
            .engine = engine,
            .flares = std.ArrayList(Flare).init(engine.allocator),
            .flare_renderer = try engine.addMeshRenderer(mat.MaterialType.echolocation, mesh.MeshType.sphere),
        };
    }

    pub fn update(self: *Flares, player_pos: [3]f32, dt: f32) void {
        const window = self.engine.window;

        // Update cooldown timer
        if (self.cooldown_timer > 0) {
            self.cooldown_timer -= dt;
        }

        if (window.getKey(.space) == .press and self.cooldown_timer <= 0) {
            const flare_mesh_id = self.flare_renderer.addInstance(player_pos, null, .{ 0.5, 0.5, 0.5 });
            const sound_id = self.engine.sound_manager.play(sm.SoundFile.siren, player_pos, FLARE_COLOR) catch @panic("cannot play flare sound");
            self.flares.append(.{
                .mesh_instance_id = flare_mesh_id,
                .sound_instance_id = sound_id,
            }) catch @panic("cannot add flare");

            // Reset cooldown timer
            self.cooldown_timer = self.cooldown_duration;
        }

        for (self.flares.items) |*flare| {
            const instance = self.flare_renderer.getInstance(flare.mesh_instance_id) orelse continue;

            // update mesh instance position
            instance.position = .{
                instance.position[0] + flare.velocity[0] * dt,
                instance.position[1] + flare.velocity[1] * dt,
                instance.position[2] + flare.velocity[2] * dt,
            };
            // update velocity with graviry
            flare.velocity = .{
                flare.velocity[0] + Constants.GRAVITY[0] * dt,
                flare.velocity[1] + Constants.GRAVITY[1] * dt,
                flare.velocity[2] + Constants.GRAVITY[2] * dt,
            };

            // update sound position
            if (self.engine.sound_manager.getSound(flare.sound_instance_id)) |sound| {
                sound.position = instance.position;
                sound.velocity = flare.velocity;
            }
        }

        // if flare is bellow ground, remove
        var i: usize = self.flares.items.len;
        while (i > 0) {
            i -= 1;
            const flare = self.flares.items[i];
            const sound_id = flare.sound_instance_id;
            const should_remove = if (self.flare_renderer.getInstance(flare.mesh_instance_id)) |instance|
                instance.position[1] < 1.0
            else
                true;

            if (should_remove) {
                _ = self.flares.orderedRemove(i);
                self.engine.sound_manager.stop(sound_id);
                if (self.flare_renderer.getInstance(flare.mesh_instance_id)) |instance| {
                    _ = self.engine.sound_manager.play(sm.SoundFile.explosion_medium, .{ instance.position[0], instance.position[1], instance.position[2] }, EXPLOSION_COLOR) catch @panic("cannot play explosion sound");
                }
            }
        }
    }

    pub fn deinit(self: *Flares) void {
        self.flares.deinit();
    }
};

pub const Flare = struct {
    velocity: [3]f32 = .{ 0.0, 20.0, 30.0 },
    mesh_instance_id: u32,
    sound_instance_id: u32,
};
