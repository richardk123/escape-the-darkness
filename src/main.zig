const std = @import("std");
const zglfw = @import("zglfw");
const mesh_loader = @import("mesh_loader.zig");
const GPUEngine = @import("gpu_engine.zig").GPUEngine;
const GUI = @import("gui.zig").GUI;
const window_title = "Escape the darkness";

pub fn main() !void {
    try zglfw.init();
    defer zglfw.terminate();

    // Change current working directory to where the executable is located.
    {
        var buffer: [1024]u8 = undefined;
        const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
        std.posix.chdir(path) catch {};
    }

    zglfw.windowHint(.client_api, .no_api);

    const window = try zglfw.Window.create(1600, 1000, window_title, null);
    defer window.destroy();
    window.setSizeLimits(400, 400, -1, -1);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try mesh_loader.loadMeshes(allocator);

    var gpuEngine = try GPUEngine.init(allocator, window);
    defer gpuEngine.deinit(allocator);

    var gui = GUI.init(allocator, window, &gpuEngine);
    defer gui.deinit();

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        zglfw.pollEvents();
        gui.update(&gpuEngine);
        gpuEngine.draw();
    }
}

test {
    std.testing.refAllDecls(@This());
}
