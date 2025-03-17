const std = @import("std");
const zaudio = @import("zaudio");
const Constants = @import("../constants.zig");

// Define the enum of predefined sound files
pub const SoundFile = enum {
    rumble,
    music,
    // Returns the file path for each sound
    pub fn getPath(self: SoundFile) [:0]const u8 {
        return switch (self) {
            .rumble => "content/sound/rumble.flac",
            .music => "content/sound/music.mp3",
        };
    }
};

// Make SoundData aligned for GPU
pub const SoundData = extern struct {
    position: [3]f32,
    // Add padding to ensure alignment
    _pad1: f32 = 0.0,
    velocity: [3]f32,
    // Add padding to ensure alignment
    _pad2: f32 = 0.0,
    frame: u32 = 0,
    // Add padding to ensure 16-byte alignment for the entire struct
    _pad3: [3]f32 = .{ 0, 0, 0 },

    pub fn init(position: [3]f32) SoundData {
        return SoundData{
            .position = position,
            .velocity = .{ 0, 0, 0 },
        };
    }

    pub fn updatePosition(self: *SoundData, position: [3]f32) void {
        self.velocity = .{ self.position[0] - position[0], self.position[1] - position[1], self.position[2] - position[2] };
        self.position = position;
    }
};

// Complete uniform buffer structure with count and fixed array
pub const SoundUniform = extern struct {
    count: u32,
    _pad: [3]u32 = .{ 0, 0, 0 }, // Padding for alignment
    data: [Constants.MAX_SOUND_COUNT]SoundData,

    pub fn init() SoundUniform {
        var uniform = SoundUniform{
            .count = 0,
            .data = undefined,
        };
        // Initialize all sound data entries
        for (&uniform.data) |*data| {
            data.* = SoundData.init(.{ 0, 0, 0 });
        }
        return uniform;
    }
};

// Verify alignment
comptime {
    if (@sizeOf(SoundData) % 16 != 0) {
        @compileError("SoundData must be 16-byte aligned for WebGPU. Current size: " ++ std.fmt.comptimePrint("{}", .{@sizeOf(SoundData)}));
    }
    if (@sizeOf(SoundUniform) % 16 != 0) {
        @compileError("SoundUniform must be 16-byte aligned for WebGPU. Current size: " ++ std.fmt.comptimePrint("{}", .{@sizeOf(SoundUniform)}));
    }
}

pub const SoundInstance = struct {
    sound: *zaudio.Sound,
    data_index: usize, // Index into the SoundData array
    id: usize,
};

pub const SoundManager = struct {
    allocator: std.mem.Allocator,
    engine: *zaudio.Engine,
    sound_instances: std.ArrayList(SoundInstance),
    uniform: SoundUniform,
    next_sound_id: usize,

    pub fn init(allocator: std.mem.Allocator) !SoundManager {
        zaudio.init(allocator);
        const engine = try zaudio.Engine.create(null);
        const sound_instances = try std.ArrayList(SoundInstance).initCapacity(allocator, Constants.MAX_SOUND_COUNT);

        return SoundManager{
            .allocator = allocator,
            .engine = engine,
            .sound_instances = sound_instances,
            .uniform = SoundUniform.init(),
            .next_sound_id = 0,
        };
    }

    // Play sound and return a handle (ID) to update it later
    pub fn play(self: *SoundManager, file: SoundFile, initial_data: SoundData) !usize {
        if (self.uniform.count >= Constants.MAX_SOUND_COUNT) {
            return error.TooManySounds;
        }

        var sound = try self.engine.createSoundFromFile(
            file.getPath(),
            .{ .flags = .{ .stream = true } },
        );

        // Set initial position
        sound.setPosition(initial_data.position);

        // Create sound instance with unique ID
        const sound_id = self.next_sound_id;
        self.next_sound_id += 1;

        // Add to sound data array
        const data_index = self.uniform.count;
        self.uniform.data[data_index] = initial_data;
        self.uniform.count += 1;

        try self.sound_instances.append(SoundInstance{
            .sound = sound,
            .data_index = data_index,
            .id = sound_id,
        });

        try sound.start();
        return sound_id;
    }

    // Update position for a specific sound
    pub fn updatePosition(self: *SoundManager, sound_id: usize, new_position: [3]f32) bool {
        for (self.sound_instances.items) |*instance| {
            if (instance.id == sound_id) {
                self.uniform.data[instance.data_index].updatePosition(new_position);
                instance.sound.setPosition(new_position);
                return true;
            }
        }
        return false; // Sound with given ID not found
    }

    // Update loop - call this once per frame to cleanup finished sounds
    pub fn update(self: *SoundManager) void {
        var i: usize = 0;
        while (i < self.sound_instances.items.len) {
            const instance = &self.sound_instances.items[i];
            if (!instance.sound.isPlaying()) {
                // Sound is no longer playing, clean it up
                instance.sound.destroy();

                // If this wasn't the last active sound, move the last one to this spot
                if (instance.data_index < self.uniform.count - 1) {
                    self.uniform.data[instance.data_index] = self.uniform.data[self.uniform.count - 1];

                    // Update the index of the sound instance that was moved
                    for (self.sound_instances.items) |*other_instance| {
                        if (other_instance.data_index == self.uniform.count - 1) {
                            other_instance.data_index = instance.data_index;
                            break;
                        }
                    }
                }

                self.uniform.count -= 1;
                _ = self.sound_instances.swapRemove(i);
            } else {
                const pcr_frame: u64 = instance.sound.getCursorInPcmFrames() catch 0;
                const frame = @as(u32, @intCast(pcr_frame));
                self.uniform.data[instance.data_index].frame = frame;
                i += 1;
            }
        }
    }

    // Get the entire uniform buffer for WebGPU
    pub fn getUniformBuffer(self: *const SoundManager) *const SoundUniform {
        return &self.uniform;
    }

    // Get the uniform buffer as bytes
    pub fn getUniformBufferBytes(self: *const SoundManager) []const u8 {
        return std.mem.asBytes(&self.uniform);
    }

    pub fn deinit(self: *SoundManager) void {
        for (self.sound_instances.items) |instance| {
            instance.sound.destroy();
        }
        self.sound_instances.deinit();
        self.engine.destroy();
        zaudio.deinit();
    }
};
