const std = @import("std");
const math = std.math;
const zgui = @import("zgui");
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;

const GPUEngine = @import("gpu_engine.zig").GPUEngine;
const content_dir = @import("build_options").content_dir;

pub const GUI = struct {
    pub fn init(allocator: std.mem.Allocator, window: *zglfw.Window, gpuEngine: *GPUEngine) GUI {
        zgui.init(allocator);

        const scale_factor = scale_factor: {
            const scale = window.getContentScale();
            break :scale_factor @max(scale[0], scale[1]);
        };

        _ = zgui.io.addFontFromFile(content_dir ++ "Roboto-Medium.ttf", math.floor(16.0 * scale_factor));

        zgui.backend.init(
            window,
            gpuEngine.gctx.device,
            @intFromEnum(zgpu.GraphicsContext.swapchain_format),
            @intFromEnum(wgpu.TextureFormat.undef),
        );

        zgui.getStyle().scaleAllSizes(scale_factor);
        return GUI{};
    }

    pub fn deinit(self: *GUI) void {
        _ = self;
        zgui.backend.deinit();
        zgui.deinit();
    }

    pub fn update(self: *GUI, gpuEngine: *GPUEngine) void {
        // todo: remove
        _ = self;
        zgui.backend.newFrame(
            gpuEngine.gctx.swapchain_descriptor.width,
            gpuEngine.gctx.swapchain_descriptor.height,
        );
        zgui.showDemoWindow(null);
    }
};
