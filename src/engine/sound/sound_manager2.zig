const std = @import("std");
const zaudio = @import("zaudio");
const Constants = @import("../../constants.zig");
const WavDecoder = @import("wav_decoder.zig");

// Define the enum of predefined sound files
pub const SoundFile = enum {
    rumble,
    music,
    // Returns the file path for each sound
    pub fn getPath(self: SoundFile) [:0]const u8 {
        return switch (self) {
            .rumble => "content/sound/sin.wav",
            .music => "content/sound/sample.wav",
        };
    }
};

pub const SoundData = struct {
    offset: u32,
    size: u32,
};

pub const SoundDatas = struct {
    all_sound_data: std.ArrayList(u8),
    sounds: std.ArrayList(SoundData),

    pub fn init(allocator: std.mem.Allocator) !SoundDatas {
        var all_sound_data = std.ArrayList(u8).init(allocator);
        var sounds = std.ArrayList(SoundData).init(allocator);

        var offset: u32 = 0;
        for (std.enums.values(SoundFile)) |sound_file| {
            const raw_data = try WavDecoder.decodeWav(allocator, sound_file.getPath());
            defer allocator.free(raw_data);
            const size = @as(u32, @intCast(raw_data.len));
            try sounds.append(SoundData{
                .size = size,
                .offset = offset,
            });
            try all_sound_data.appendSlice(raw_data);
            offset += size;
        }

        return SoundDatas{
            .all_sound_data = all_sound_data,
            .sounds = sounds,
        };
    }

    pub fn deinit(self: *SoundDatas) void {
        self.all_sound_data.deinit();
        self.sounds.deinit();
    }
};

pub const SoundInstanceData = struct {
    position: [3]f32,
    offset: u32,
    velocity: [3]f32,
    size: u32,
    current_frame: u32,
    // padding
    color: [3]f32,
};

pub const SoundUniform = struct {
    instance_count: u32,
    _pad: [3]f32 = .{ 0, 0, 0 },
    instances: [Constants.MAX_SOUND_COUNT]SoundInstanceData,
};

pub const SoundInstance = struct {
    sound: *zaudio.Sound,
    instance_data_index: usize,
    id: usize,
};

pub const SoundManager = struct {
    sound_datas: SoundDatas,
    engine: *zaudio.Engine,
    sound_instances: std.ArrayList(SoundInstance),
    sound_id: usize = 0,

    pub fn init(allocator: std.mem.Allocator) !SoundManager {
        const sound_datas = try SoundDatas.init(allocator);
        zaudio.init(allocator);
        const engine = try zaudio.Engine.create(null);
        const sound_instances = std.ArrayList(SoundInstance).init(allocator);

        return SoundManager{
            .sound_datas = sound_datas,
            .engine = engine,
            .sound_instances = sound_instances,
        };
    }

    pub fn play(self: *SoundManager, soundFile: SoundFile) !usize {
        const sound = try self.engine.createSoundFromFile(soundFile.getPath(), .{ .flags = .{ .stream = true } });
        std.debug.print("playing sound {s} \n", .{soundFile.getPath()});
        try sound.start();

        self.sound_id += 1;
        try self.sound_instances.append(SoundInstance{
            .id = self.sound_id,
            .instance_data_index = 0,
            .sound = sound,
        });

        return self.sound_id;
    }

    pub fn deinit(self: *SoundManager) void {
        for (self.sound_instances.items) |instance| {
            instance.sound.destroy();
        }
        self.sound_datas.deinit();
        self.sound_instances.deinit();
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
