// const std = @import("std");
// const math = std.math;
// const zgui = @import("zgui");
// const zglfw = @import("zglfw");
// const zgpu = @import("zgpu");
// const wgpu = zgpu.wgpu;

// const GPUEngine = @import("renderer/gpu_engine.zig").GPUEngine;
// const content_dir = @import("build_options").content_dir;

// pub const GUI = struct {
//     drag1: f32,
//     drag2: f32,

//     pub fn init(allocator: std.mem.Allocator, window: *zglfw.Window, gpuEngine: *GPUEngine) GUI {
//         zgui.init(allocator);

//         const scale_factor = scale_factor: {
//             const scale = window.getContentScale();
//             break :scale_factor @max(scale[0], scale[1]);
//         };

//         _ = zgui.io.addFontFromFile(content_dir ++ "Roboto-Medium.ttf", math.floor(16.0 * scale_factor));

//         zgui.backend.init(
//             window,
//             gpuEngine.gctx.device,
//             @intFromEnum(zgpu.GraphicsContext.swapchain_format),
//             @intFromEnum(wgpu.TextureFormat.undef),
//         );

//         zgui.getStyle().scaleAllSizes(scale_factor);
//         return GUI{
//             .drag1 = 0.0,
//             .drag2 = 0.0,
//         };
//     }

//     pub fn deinit(self: *GUI) void {
//         _ = self;
//         zgui.backend.deinit();
//         zgui.deinit();
//     }

//     pub fn update(self: *GUI, gpuEngine: *GPUEngine) void {
//         zgui.backend.newFrame(
//             gpuEngine.gctx.swapchain_descriptor.width,
//             gpuEngine.gctx.swapchain_descriptor.height,
//         );

//         const window_height: f32 = @floatFromInt(gpuEngine.gctx.swapchain_descriptor.height);
//         zgui.setNextWindowPos(.{ .x = 0.0, .y = 0.0 });
//         zgui.setNextWindowSize(.{ .w = 800.0, .h = window_height });

//         zgui.bulletText("W, A, S, D :  move camera", .{});
//         zgui.spacing();

//         zgui.text("FPS: {d:.0}", .{zgui.io.getFramerate()});
//         zgui.text("Mouse Pos: {d:.0} {d:.0}", .{ zgui.getMousePos()[0], zgui.getMousePos()[1] });

//         if (zgui.button("Setup Scene", .{})) {
//             // Button pressed.
//         }

//         if (zgui.dragFloat("Drag 1", .{ .v = &self.drag1 })) {
//             // value0 has changed
//         }

//         if (zgui.dragFloat("Drag 2", .{ .v = &self.drag2, .min = -1.0, .max = 1.0 })) {
//             // value1 has changed
//         }
//     }
// };
