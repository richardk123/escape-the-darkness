const std = @import("std");
const math = std.math;
const zgui = @import("zgui");
const zm = @import("zmath");
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const content_dir = @import("build_options").content_dir;

const Engine = @import("../engine/engine.zig").Engine;
const SoundFile = @import("../engine/sound/sound_manager.zig").SoundFile;
const mr = @import("../engine/mesh_renderer.zig");

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
            // Controls section
            zgui.bulletText("W, A, S, D :  move camera", .{});
            zgui.spacing();
            zgui.spacing();

            // FPS and mouse info
            zgui.text("FPS: {d:.0}", .{zgui.io.getFramerate()});
            zgui.text("Mouse Pos: {d:.0} {d:.0}", .{ zgui.getMousePos()[0], zgui.getMousePos()[1] });
            zgui.spacing();
            zgui.separator();
            zgui.spacing();

            // Camera Eye Position
            if (zgui.collapsingHeader("Camera Position", .{ .default_open = true })) {
                zgui.spacing();
                zgui.indent(.{ .indent_w = 20 });
                _ = zgui.dragFloat("X##eye", .{ .v = &self.engine.camera.position[0], .speed = 0.1 });
                _ = zgui.dragFloat("Y##eye", .{ .v = &self.engine.camera.position[1], .speed = 0.1 });
                _ = zgui.dragFloat("Z##eye", .{ .v = &self.engine.camera.position[2], .speed = 0.1 });
                zgui.unindent(.{ .indent_w = 20 });
                zgui.spacing();
            }

            zgui.spacing();
            zgui.separator();
            zgui.spacing();
            for (self.engine.mesh_renderers.mesh_renderers.items, 0..) |renderer, i| {
                for (renderer.instances.items, 0..) |*instance, j| {
                    var label_buf: [64]u8 = undefined;
                    const label = std.fmt.bufPrintZ(&label_buf, "Mesh {d} - Instance {d}", .{ i, j }) catch "Instance";
                    renderMeshInstanceControls(instance, label);
                }
            }
            zgui.separator();
            zgui.spacing();

            // Add sound controls section
            if (zgui.collapsingHeader("Sound Controls", .{ .default_open = true })) {
                zgui.spacing();
                zgui.indent(.{ .indent_w = 20 });

                for (std.enums.values(SoundFile)) |sound_file| {
                    self.renderPlaySoundButton(sound_file);
                }

                zgui.unindent(.{ .indent_w = 20 });
                zgui.spacing();
            }

            zgui.spacing();
            zgui.separator();
            zgui.spacing();

            // Reset Camera Button
            if (zgui.button("Reset Camera", .{})) {
                self.engine.camera.position = .{ 0.0, 2.0, 0.0 };
            }
        }

        self.renderSoundUniform();

        zgui.end();
    }

    // Add this to the GUI struct in gui.zig
    pub fn renderMeshInstanceControls(instance: *mr.MeshInstance, label: [:0]const u8) void {
        if (zgui.collapsingHeader(label, .{ .default_open = false })) {
            zgui.spacing();
            zgui.indent(.{ .indent_w = 20 });

            // Position controls
            if (makeTreeNode("Position##pos_{s}", .{label})) {
                makeDragFloat(&instance.position[0], "X##posx_{s}", .{label});
                makeDragFloat(&instance.position[1], "Y##pos_{s}", .{label});
                makeDragFloat(&instance.position[2], "Z##pos_{s}", .{label});
                zgui.treePop();
            }

            // Rotation controls (quaternion)
            if (makeTreeNode("Rotation##rot_{s}", .{label})) {
                makeDragFloat(&instance.euler_angles[0], "X##rot_{s}", .{label});
                makeDragFloat(&instance.euler_angles[1], "Y##rot_{s}", .{label});
                makeDragFloat(&instance.euler_angles[2], "Z##rot_{s}", .{label});
                instance.rotation = zm.quatFromRollPitchYaw(instance.euler_angles[0], instance.euler_angles[1], instance.euler_angles[2]);
                zgui.treePop();
            }

            // Scale controls
            if (makeTreeNode("Scale##scale_{s}", .{label})) {
                makeDragFloat(&instance.scale[0], "X##scale_{s}", .{label});
                makeDragFloat(&instance.scale[1], "Y##scale_{s}", .{label});
                makeDragFloat(&instance.scale[2], "Z##scale_{s}", .{label});
                zgui.treePop();
            }

            zgui.unindent(.{ .indent_w = 20 });
            zgui.spacing();
        }
    }

    fn makeTreeNode(comptime fmt: []const u8, args: anytype) bool {
        var buf: [64]u8 = undefined;
        const node_id = std.fmt.bufPrintZ(&buf, fmt, args) catch unreachable;
        return zgui.treeNodeFlags(node_id, .{ .default_open = true });
    }

    fn makeDragFloat(value: *f32, comptime fmt: []const u8, args: anytype) void {
        var buf: [64]u8 = undefined;
        const label = std.fmt.bufPrintZ(&buf, fmt, args) catch unreachable;
        _ = zgui.dragFloat(label, .{ .v = value, .speed = 0.1 });
    }

    fn renderPlaySoundButton(self: *GUI, sound: SoundFile) void {
        // Create a fixed buffer for the button label - make it large enough for any tag name
        var buffer: [64:0]u8 = undefined;

        // Get the tag name
        const tag_str = std.enums.tagName(SoundFile, sound) orelse "Unknown";

        // Create a null-terminated string in our buffer
        const button_text = std.fmt.bufPrintZ(&buffer, "Play {s}", .{tag_str}) catch "Play";
        if (zgui.button(button_text, .{})) {
            _ = self.engine.sound_manager.play(sound, .{ 0.0, 2.0, 0.0 }, .{ 1, 0, 0 }) catch |err| {
                std.debug.print("Failed to play rumble sound: {}\n", .{err});
            };
        }
    }

    fn renderSoundUniform(self: *GUI) void {
        zgui.spacing();
        zgui.separator();
        zgui.spacing();

        // Add SoundUniform information section
        if (zgui.collapsingHeader("Sound Uniform Info", .{ .default_open = true })) {
            zgui.spacing();
            zgui.indent(.{ .indent_w = 20 });

            // Display active sound count
            zgui.text("Active Sounds: {d}", .{self.engine.sound_manager.uniform.count});

            // Display information about each active sound instance
            if (self.engine.sound_manager.uniform.count > 0) {
                zgui.separator();
                for (0..self.engine.sound_manager.uniform.count) |i| {
                    const instance = self.engine.sound_manager.uniform.instances[i];

                    zgui.text("Instance {d}:", .{i});
                    zgui.sameLine(.{});
                    zgui.text("Offset: {d}", .{instance.offset});
                    zgui.sameLine(.{});
                    zgui.text("Size: {d}", .{instance.size});
                    zgui.sameLine(.{});
                    zgui.text("Frame: {d}", .{instance.current_frame});

                    if (i < self.engine.sound_manager.uniform.count - 1) {
                        zgui.separator();
                    }
                }
            }

            zgui.unindent(.{ .indent_w = 20 });
            zgui.spacing();
        }
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
