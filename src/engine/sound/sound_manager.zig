const std = @import("std");
const zaudio = @import("zaudio");
const Constants = @import("../common//constants.zig");
const WavDecoder = @import("wav_decoder.zig");

// Define the enum of predefined sound files
pub const SoundFile = enum {
    deep,
    rumble,
    music,
    blip,
    water_drop,
    // Returns the file path for each sound
    pub fn getPath(self: SoundFile) [:0]const u8 {
        return switch (self) {
            .deep => "content/sound/80hz.wav",
            .rumble => "content/sound/sin.wav",
            .music => "content/sound/sample.wav",
            .blip => "content/sound/Blip_Select8.wav",
            .water_drop => "content/sound/water-drop.wav",
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
            const raw_data = try WavDecoder.decodeWav(allocator, sound_file.getPath());
            defer allocator.free(raw_data);
            const size = @as(u32, @intCast(raw_data.len));
            try sounds.append(SoundData{
                .size = size,
                .offset = offset,
                .sound_file = sound_file,
            });
            try sounds_texture_data.appendSlice(raw_data);
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
};

pub const SoundManager = struct {
    data: SoundDatas,
    engine: *zaudio.Engine,
    instances: std.ArrayList(SoundInstance),
    next_id: usize = 0,
    uniform: SoundUniform,

    pub fn init(allocator: std.mem.Allocator, max_texture_size_2d: u32) !SoundManager {
        zaudio.init(allocator);
        const sound_datas = try SoundDatas.init(allocator, max_texture_size_2d);
        const engine = try zaudio.Engine.create(null);
        const sound_instances = std.ArrayList(SoundInstance).init(allocator);
        const sound_uniform = SoundUniform.init();

        return SoundManager{
            .data = sound_datas,
            .engine = engine,
            .instances = sound_instances,
            .uniform = sound_uniform,
        };
    }

    pub fn play(self: *SoundManager, sound_file: SoundFile, position: [3]f32) !usize {
        const sound = try self.engine.createSoundFromFile(sound_file.getPath(), .{ .flags = .{ .stream = true } });
        try sound.start();

        const sound_data = self.data.findSoundData(sound_file);

        try self.instances.append(SoundInstance{
            .id = self.next_id,
            .sound = sound,
            .instance_data_index = self.instances.items.len,
            .position = position,
        });

        self.next_id += 1;

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

    // Update loop - call this once per frame to cleanup finished sounds
    pub fn update(self: *SoundManager) void {
        // Iterate backwards to safely remove elements
        var i: usize = self.instances.items.len;
        while (i > 0) {
            i -= 1;
            const instance = self.instances.items[i];

            if (!instance.sound.isPlaying()) {
                // Sound is no longer playing, clean it up
                instance.sound.destroy();

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
            } else {
                // update pcr_frame
                if (instance.instance_data_index < self.uniform.count) {
                    const pcr_frame: u64 = instance.sound.getCursorInPcmFrames() catch 0;
                    const frame = @as(u32, @intCast(pcr_frame));
                    self.uniform.instances[instance.instance_data_index].current_frame = frame;
                    self.uniform.instances[instance.instance_data_index].position = instance.position;
                }
            }
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
