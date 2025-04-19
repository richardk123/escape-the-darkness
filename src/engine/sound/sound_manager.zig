const std = @import("std");
const zaudio = @import("zaudio");
const Utils = @import("../common/utils.zig");

const Constants = @import("../common/constants.zig");
const WavDecoder = @import("wav_decoder.zig");
const Camera = @import("../camera.zig").Camera;

// Enum of predefined sound files
pub const SoundFile = enum {
    deep,
    music,
    water_drop,
    explosion_medium,
    flare,
    // Returns the file path for each sound
    pub fn getPath(self: SoundFile) [:0]const u8 {
        return switch (self) {
            .deep => "content/sound/80hz.wav",
            .music => "content/sound/sample.wav",
            .water_drop => "content/sound/water-drop.wav",
            .explosion_medium => "content/sound/medium-explosion.wav",
            .flare => "content/sound/3000.wav",
        };
    }
};

pub const SoundData = struct {
    offset: u32,
    size: u32,
    sound_file: SoundFile,
};

pub const SoundDatas = struct {
    sounds_texture_data: std.ArrayList(u8),
    sounds: std.ArrayList(SoundData),

    pub fn init(allocator: std.mem.Allocator, max_texture_size_2d: u32) !SoundDatas {
        var sounds_texture_data = std.ArrayList(u8).init(allocator);
        var sounds = std.ArrayList(SoundData).init(allocator);

        var offset: u32 = 0;
        for (std.enums.values(SoundFile)) |sound_file| {
            // Decode the raw WAV data
            const raw_data = try WavDecoder.decodeWav(allocator, sound_file.getPath());
            defer allocator.free(raw_data);

            // Smooth the audio data before storing it
            const smoothed_data = try smoothAmplitudeData(allocator, raw_data);
            defer allocator.free(smoothed_data);

            const size = @as(u32, @intCast(smoothed_data.len));
            try sounds.append(SoundData{
                .size = size,
                .offset = offset,
                .sound_file = sound_file,
            });

            try sounds_texture_data.appendSlice(smoothed_data);
            offset += size;
        }

        // Calculate texture dimensions
        const pixel_data_len = sounds_texture_data.items.len / 4;
        const width = max_texture_size_2d;
        const height = (pixel_data_len + width - 1) / width; // Ceiling division
        const total_pixels = width * height;
        const total_bytes = total_pixels * 4;

        // Add padding to match exact texture size
        if (sounds_texture_data.items.len < total_bytes) {
            const padding_bytes = total_bytes - sounds_texture_data.items.len;
            try sounds_texture_data.appendNTimes(0, padding_bytes);
        }

        return SoundDatas{
            .sounds_texture_data = sounds_texture_data,
            .sounds = sounds,
        };
    }

    fn smoothAmplitudeData(allocator: std.mem.Allocator, raw_data: []const u8) ![]u8 {
        // Create a buffer for the smoothed data
        var smoothed = try allocator.alloc(u8, raw_data.len);

        // Constants for envelope following (adjust these to your preference)
        const attack_time: f32 = 0.005; // Fast attack to catch transients (in seconds)
        const release_time: f32 = 0.05; // Slower release for smoother decay (in seconds)

        // Convert to coefficients assuming 48kHz sample rate
        // Adjust these values based on your actual sample rate
        const sample_rate: f32 = 48000.0;
        const attack_coef = std.math.exp(-1.0 / (attack_time * sample_rate));
        const release_coef = std.math.exp(-1.0 / (release_time * sample_rate));

        // Initialize envelope with first sample
        var envelope: f32 = if (raw_data.len > 0) @floatFromInt(raw_data[0]) else 0.0;

        // Process each sample
        for (raw_data, 0..) |sample, i| {
            const sample_value: f32 = @floatFromInt(sample);

            // Envelope follower with different attack/release times
            if (sample_value > envelope) {
                // Fast attack for rising signals
                envelope = attack_coef * envelope + (1.0 - attack_coef) * sample_value;
            } else {
                // Slower release for falling signals
                envelope = release_coef * envelope + (1.0 - release_coef) * sample_value;
            }

            // Store the result
            smoothed[i] = @intFromFloat(std.math.clamp(envelope, 0.0, 255.0));
        }

        return smoothed;
    }

    pub fn findSoundData(self: SoundDatas, sound_file: SoundFile) SoundData {
        for (self.sounds.items) |sound| {
            if (sound.sound_file == sound_file) {
                return sound;
            }
        }
        var msg_buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "Sound data not found for sound file: {s}", .{@tagName(sound_file)}) catch "Sound data not found (couldn't format error message)";

        @panic(msg);
    }

    pub fn deinit(self: *SoundDatas) void {
        self.sounds_texture_data.deinit();
        self.sounds.deinit();
    }
};

pub const SoundInstanceData = extern struct {
    offset: u32 = 0,
    size: u32 = 0,
    current_frame: u32 = 0,
    _padding1: u32 = 0,
    position: [3]f32,
    _padding2: u32 = 0,
};

pub const SoundUniform = struct {
    count: u32,
    _pad: [3]f32 = .{ 0, 0, 0 },
    instances: [Constants.MAX_SOUND_COUNT]SoundInstanceData,

    pub fn init() SoundUniform {
        var uniform = SoundUniform{
            .count = 0,
            .instances = undefined,
        };
        // Initialize all sound data entries
        for (&uniform.instances) |*data| {
            data.* = .{ .position = .{ 0.0, 0.0, 0.0 } };
        }
        return uniform;
    }
};

pub const SoundInstance = struct {
    sound: *zaudio.Sound,
    instance_data_index: usize,
    id: usize,
    position: [3]f32 = .{ 0.0, 0.0, 0.0 },
    velocity: [3]f32 = .{ 0.0, 0.0, 0.0 },
    // used for delay when player hears the sound
    startDelay: f32 = 0,
    // used for delay after sound played
    finishDelay: f32 = 0,
    // time to calculate pcr
    renderTime: f32 = 0,
    started: bool = false,
};

pub const SoundManager = struct {
    data: SoundDatas,
    engine: *zaudio.Engine,
    instances: std.ArrayList(SoundInstance),
    next_id: u32 = 0,
    uniform: SoundUniform,

    pub fn init(allocator: std.mem.Allocator, max_texture_size_2d: u32) !SoundManager {
        zaudio.init(allocator);
        const sound_datas = try SoundDatas.init(allocator, max_texture_size_2d);
        const engine = try zaudio.Engine.create(null);
        const sound_instances = std.ArrayList(SoundInstance).init(allocator);
        const sound_uniform = SoundUniform.init();
        engine.setListenerPosition(0, .{ 0, 0, 0 });
        // engine.setListenerVelocity(0, .{ 0, 0, 0 });
        // engine.setListenerDirection(0, .{ 0, 0, -1 });

        return SoundManager{
            .data = sound_datas,
            .engine = engine,
            .instances = sound_instances,
            .uniform = sound_uniform,
        };
    }

    pub fn play(self: *SoundManager, sound_file: SoundFile, position: [3]f32) !u32 {
        const sound = try self.engine.createSoundFromFile(sound_file.getPath(), .{ .flags = .{ .stream = true } });
        sound.setSpatializationEnabled(true);
        sound.setDopplerFactor(5.0);
        sound.setMinDistance(0.1);
        sound.setMaxDistance(1000.0);
        sound.setAttenuationModel(.linear);
        sound.setVolume(5.0);
        const sound_data = self.data.findSoundData(sound_file);

        self.next_id += 1;

        try self.instances.append(SoundInstance{
            .id = self.next_id,
            .sound = sound,
            .instance_data_index = self.instances.items.len,
            .position = position,
        });

        if (self.instances.items.len <= Constants.MAX_SOUND_COUNT) {
            var uniform_sound_data = &self.uniform.instances[self.instances.items.len - 1];
            uniform_sound_data.size = sound_data.size;
            uniform_sound_data.offset = sound_data.offset;
            uniform_sound_data.current_frame = 0;
            uniform_sound_data.position = position;
            self.uniform.count += 1;
        }

        return self.next_id;
    }

    pub fn stop(self: *SoundManager, id: u32) void {
        if (self.getSound(id)) |sound_instance| {
            // Find the index in the instances array
            for (self.instances.items, 0..) |instance, i| {
                if (instance.id == id) {
                    self.removeSoundInstance(sound_instance, i);
                    break;
                }
            }
        }
    }

    pub fn getSound(self: *SoundManager, id: u32) ?*SoundInstance {
        for (self.instances.items) |*instance| {
            if (instance.id == id) {
                return instance;
            }
        }
        return null;
    }

    // Update loop - call this once per frame to cleanup finished sounds
    pub fn update(self: *SoundManager, camera: *Camera, dt: f32) void {
        self.engine.setListenerPosition(0, camera.position);
        // self.engine.setListenerVelocity(0, .{ 0, 0, 0 });
        self.engine.setListenerDirection(0, camera.forward);

        // Iterate backwards to safely remove elements
        var i: usize = self.instances.items.len;
        while (i > 0) {
            i -= 1;
            var instance = &self.instances.items[i];
            const sound = instance.sound;
            instance.startDelay += dt;

            const distance = Utils.distance(camera.position, instance.position);
            const sound_traveled_distance = Constants.SPEED_OF_SOUND * instance.startDelay;
            const canPlay = distance < sound_traveled_distance;

            if (canPlay and !instance.started) {
                // sound arrived to player
                sound.start() catch std.debug.print("cannot start sound", .{});
                instance.started = true;
            } else if (!sound.isPlaying() and instance.started) {
                instance.finishDelay += dt;

                if (instance.finishDelay > Constants.SOUND_FINISH_DELAY) {
                    // Sound is no longer visible, clean it up
                    self.removeSoundInstance(instance, i);
                } else {
                    // just render sound
                    self.updateSoundInstance(instance, dt);
                }
            } else if (sound.isPlaying()) {
                // sound is playing
                self.updateSoundInstance(instance, dt);
            }
        }
    }

    fn removeSoundInstance(self: *SoundManager, instance: *SoundInstance, i: usize) void {
        const sound = instance.sound;
        sound.destroy();

        // If this wasn't the last active sound, move the last one to this spot
        if (instance.instance_data_index < self.uniform.count - 1) {
            self.uniform.instances[instance.instance_data_index] = self.uniform.instances[self.uniform.count - 1];

            // Update the index of the sound instance that was moved
            for (self.instances.items) |*other_instance| {
                if (other_instance.instance_data_index == self.uniform.count - 1) {
                    other_instance.instance_data_index = instance.instance_data_index;
                    break;
                }
            }
        }

        self.uniform.count -= 1;
        _ = self.instances.swapRemove(i);
    }

    fn updateSoundInstance(self: *SoundManager, instance: *SoundInstance, dt: f32) void {
        // sound is playing
        if (instance.instance_data_index < self.uniform.count) {
            instance.sound.setVelocity(instance.velocity);
            instance.renderTime += dt;
            const frame: u32 = @as(u32, @intFromFloat(instance.renderTime * Constants.SOUND_SAMPLE_RATE));
            self.uniform.instances[instance.instance_data_index].current_frame = frame;
            self.uniform.instances[instance.instance_data_index].position = instance.position;
        }
    }

    pub fn deinit(self: *SoundManager) void {
        for (self.instances.items) |instance| {
            instance.sound.destroy();
        }
        self.data.deinit();
        self.instances.deinit();
        self.engine.destroy();
        zaudio.deinit();
    }
};

// Verify alignment
comptime {
    if (@sizeOf(SoundInstanceData) % 16 != 0) {
        @compileError("SoundInstanceData must be 16-byte aligned for WebGPU. Current size: " ++ std.fmt.comptimePrint("{}", .{@sizeOf(SoundInstanceData)}));
    }
    if (@sizeOf(SoundUniform) % 16 != 0) {
        @compileError("SoundUniform must be 16-byte aligned for WebGPU. Current size: " ++ std.fmt.comptimePrint("{}", .{@sizeOf(SoundUniform)}));
    }
}
