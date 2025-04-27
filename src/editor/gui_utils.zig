const zgui = @import("zgui");
const std = @import("std");

pub fn inputU32(label: [:0]const u8, value: *u32) void {
    var temp_min: i32 = @as(i32, @intCast(value.*));
    if (zgui.inputInt(label, .{ .v = &temp_min })) {
        // Only update if non-negative
        if (temp_min >= 0) {
            value.* = @as(u32, @intCast(temp_min));
        }
    }
}

pub const StrGen = struct {
    buffer: [64]u8 = undefined,
    name: [:0]u8 = undefined,

    pub fn init() StrGen {
        return .{ .buffer = undefined, .name = undefined };
    }

    pub fn getId(self: *StrGen, label: []const u8, index: usize) [:0]const u8 {
        self.name = std.fmt.bufPrintZ(&self.buffer, "{s}##{d}", .{ label, index }) catch @panic("cannot generate id");
        return self.name;
    }

    pub fn getName(self: *StrGen, label: []const u8, index: usize) [:0]const u8 {
        self.name = std.fmt.bufPrintZ(&self.buffer, "{s} {d}", .{ label, index }) catch @panic("cannot generate name");
        return self.name;
    }

    pub fn tranform(self: *StrGen, label: []const u8) [:0]const u8 {
        self.name = std.fmt.bufPrintZ(&self.buffer, "{s}", .{label}) catch @panic("cannot transform to [:0]");
        return self.name;
    }
};
