const std = @import("std");
const math = std.math;
const zgui = @import("zgui");
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const content_dir = @import("build_options").content_dir;

const Engine = @import("engine/engine.zig").Engine;

pub const GUI = struct {
    engine: *Engine,

    pub fn init(
        allocator: std.mem.Allocator,
        window: *zglfw.Window,
        engine: *Engine,
    ) GUI {
        zgui.init(allocator);

        const scale_factor = scale_factor: {
            const scale = window.getContentScale();
            break :scale_factor @max(scale[0], scale[1]);
        };

        _ = zgui.io.addFontFromFile(content_dir ++ "Roboto-Medium.ttf", math.floor(16.0 * scale_factor));

        zgui.backend.init(
            window,
            engine.renderer.gctx.device,
            @intFromEnum(zgpu.GraphicsContext.swapchain_format),
            @intFromEnum(wgpu.TextureFormat.undef),
        );

        zgui.getStyle().scaleAllSizes(scale_factor);
        return GUI{
            .engine = engine,
        };
    }

    pub fn update(self: *GUI) void {
        const gctx = self.engine.renderer.gctx;
        zgui.backend.newFrame(
            gctx.swapchain_descriptor.width,
            gctx.swapchain_descriptor.height,
        );

        const window_height: f32 = @floatFromInt(gctx.swapchain_descriptor.height);
        zgui.setNextWindowPos(.{ .x = 0.0, .y = 0.0 });
        zgui.setNextWindowSize(.{ .w = 800.0, .h = window_height });

        if (zgui.begin("Camera Controls", .{ .flags = .{} })) {
            zgui.bulletText("W, A, S, D :  move camera", .{});
            zgui.spacing();

            zgui.text("FPS: {d:.0}", .{zgui.io.getFramerate()});
            zgui.text("Mouse Pos: {d:.0} {d:.0}", .{ zgui.getMousePos()[0], zgui.getMousePos()[1] });

            zgui.separator();

            // Camera Eye Position
            if (zgui.collapsingHeader("Camera Position", .{})) {
                _ = zgui.dragFloat("X##eye", .{ .v = &self.engine.camera.position[0], .speed = 0.1 });
                _ = zgui.dragFloat("Y##eye", .{ .v = &self.engine.camera.position[1], .speed = 0.1 });
                _ = zgui.dragFloat("Z##eye", .{ .v = &self.engine.camera.position[2], .speed = 0.1 });
            }

            zgui.separator();

            // Reset Camera Button
            if (zgui.button("Reset Camera", .{})) {
                self.engine.camera.position = .{ 0, 4.0, 40.0 };
            }
        }
        zgui.end();
    }

    pub fn draw(self: *GUI) !void {
        const gctx = self.engine.renderer.gctx;
        const encoder = self.engine.renderer.encoder;

        const back_buffer_view = gctx.swapchain.getCurrentTextureView();
        const color_attachments = [_]wgpu.RenderPassColorAttachment{.{
            .view = back_buffer_view,
            .load_op = .load,
            .store_op = .store,
        }};
        const render_pass_info = wgpu.RenderPassDescriptor{
            .color_attachment_count = color_attachments.len,
            .color_attachments = &color_attachments,
        };
        const pass = encoder.beginRenderPass(render_pass_info);
        defer {
            pass.end();
            pass.release();
        }
        zgui.backend.draw(pass);
    }

    pub fn deinit(self: *GUI) void {
        _ = self;
        zgui.backend.deinit();
        zgui.deinit();
    }
};
