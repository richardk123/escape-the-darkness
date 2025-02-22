const zgui = @import("zgui");
const GPUEngine = @import("gpu_engine.zig").GPUEngine;

pub const GUI = struct {
    pub fn init() GUI {
        return GUI{};
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
