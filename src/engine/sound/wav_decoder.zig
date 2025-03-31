const std = @import("std");

const WavHeader = extern struct {
    chunk_iD: [4]u8,
    chunk_size: u32,
    format: [4]u8,
    subchunk1_id: [4]u8,
    subchunk1_size: u32,
    audio_format: u16,
    num_channels: u16,
    sample_rate: u32,
    byte_rate: u32,
    block_align: u16,
    bits_per_sample: u16,
    subchunk2_id: [4]u8,
    subchunk2_size: u32,
};

pub fn decodeWav(allocator: std.mem.Allocator, file_path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    var reader = file.reader();
    var header: WavHeader = undefined;
    try reader.readNoEof(std.mem.asBytes(&header));

    std.debug.print("reading file {s} -> chunk size {} num channels {} block_align {}\n\n", .{ file_path, header.chunk_size, header.num_channels, header.block_align });

    // Read PCM data
    const pcmData = try allocator.alloc(u8, header.subchunk2_size);
    _ = try reader.readAll(pcmData);
    defer allocator.free(pcmData);

    // Convert to mono u8
    return convertToMonoU8(allocator, header, pcmData);
}

fn convertToMonoU8(allocator: std.mem.Allocator, header: WavHeader, pcmData: []const u8) ![]u8 {
    // Calculate samples per channel
    const sample_size = header.bits_per_sample / 8;
    const samples_per_channel = header.subchunk2_size / (sample_size * header.num_channels);

    // Allocate buffer for mono u8 data
    var mono_data = try allocator.alloc(u8, samples_per_channel);
    errdefer allocator.free(mono_data);

    // Convert to mono u8
    var i: usize = 0;
    while (i < samples_per_channel) : (i += 1) {
        var sample_sum: i32 = 0;

        // Average all channels for this sample
        var channel: usize = 0;
        while (channel < header.num_channels) : (channel += 1) {
            const sample_offset = i * header.num_channels * sample_size + channel * sample_size;

            // Handle different bit depths
            if (header.bits_per_sample == 8) {
                // 8-bit samples are unsigned
                sample_sum += @as(i32, pcmData[sample_offset]);
            } else if (header.bits_per_sample == 16) {
                // 16-bit samples are signed
                const sample = std.mem.readInt(i16, pcmData[sample_offset..][0..2], .little);
                // Convert from -32768..32767 to 0..255 range
                // First cast to i32 to prevent overflow, then add 32768
                sample_sum += @divTrunc(@as(i32, sample) + 32768, 256);
            } else if (header.bits_per_sample == 24) {
                // 24-bit samples are signed
                const sample_bytes = pcmData[sample_offset..][0..3];
                // Read as unsigned 24-bit first
                var sample: i32 = @as(i32, sample_bytes[0]) |
                    (@as(i32, sample_bytes[1]) << 8) |
                    (@as(i32, sample_bytes[2]) << 16);

                // Perform sign extension for negative values
                if ((sample & 0x800000) != 0) {
                    // If the sign bit is set (bit 23), set bits 24-31 to 1
                    // Use bitwise negation to handle this properly for i32
                    sample |= @as(i32, -0x1000000); // This is equivalent to setting bits 24-31 to 1
                }

                // Convert to 0..255 range
                sample_sum += @divTrunc(sample + 8388608, 65536);
            } else if (header.bits_per_sample == 32) {
                // 32-bit samples could be int or float
                // Assuming int for simplicity
                const sample = std.mem.readInt(i32, pcmData[sample_offset..][0..4], .little);
                // Convert to 0..255 range
                // Need to handle i32.max + value carefully
                var normalized: i32 = undefined;
                if (sample < 0) {
                    normalized = @divTrunc(sample + 2147483647, 16777216) + 128;
                } else {
                    normalized = @divTrunc(sample, 16777216) + 128;
                }
                sample_sum += normalized;
            }
        }

        // Average the channels
        mono_data[i] = @as(u8, @intCast(@divTrunc(sample_sum, header.num_channels)));
    }

    return mono_data;
}
