const std = @import("std");
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;

pub const Renderer = struct {
    gctx: *zgpu.GraphicsContext,
    depth_texture: zgpu.TextureHandle,
    depth_texture_view: zgpu.TextureViewHandle,
    encoder: ?wgpu.CommandEncoder = null,
    pass: ?wgpu.RenderPassEncoder = null,

    pub fn init(allocator: std.mem.Allocator, window: *zglfw.Window) !Renderer {
        const gctx = try zgpu.GraphicsContext.create(
            allocator,
            .{
                .window = window,
                .fn_getTime = @ptrCast(&zglfw.getTime),
                .fn_getFramebufferSize = @ptrCast(&zglfw.Window.getFramebufferSize),
                .fn_getWin32Window = @ptrCast(&zglfw.getWin32Window),
                .fn_getX11Display = @ptrCast(&zglfw.getX11Display),
                .fn_getX11Window = @ptrCast(&zglfw.getX11Window),
                .fn_getWaylandDisplay = @ptrCast(&zglfw.getWaylandDisplay),
                .fn_getWaylandSurface = @ptrCast(&zglfw.getWaylandWindow),
                .fn_getCocoaWindow = @ptrCast(&zglfw.getCocoaWindow),
            },
            .{},
        );
        errdefer gctx.destroy(allocator);

        const depth_texture_data = createDepthTexture(gctx);
        return Renderer{
            .gctx = gctx,
            .depth_texture = depth_texture_data.texture,
            .depth_texture_view = depth_texture_data.view,
        };
    }

    pub fn beginPass(self: *Renderer) !void {
        const gctx = self.gctx;

        const depth_view = gctx.lookupResource(self.depth_texture_view) orelse return error.DepthViewNotExist;
        const back_buffer_view = gctx.swapchain.getCurrentTextureView();

        const color_attachments = [_]wgpu.RenderPassColorAttachment{.{
            .view = back_buffer_view,
            .load_op = .clear,
            .store_op = .store,
        }};
        const depth_attachment = wgpu.RenderPassDepthStencilAttachment{
            .view = depth_view,
            .depth_load_op = .clear,
            .depth_store_op = .store,
            .depth_clear_value = 1.0,
        };
        const render_pass_info = wgpu.RenderPassDescriptor{
            .color_attachment_count = color_attachments.len,
            .color_attachments = &color_attachments,
            .depth_stencil_attachment = &depth_attachment,
        };

        const encoder = gctx.device.createCommandEncoder(null);
        const pass = encoder.beginRenderPass(render_pass_info);
        self.encoder = encoder;
        self.pass = pass;
    }

    pub fn endPass(self: *Renderer) !void {
        const gctx = self.gctx;

        const back_buffer_view = gctx.swapchain.getCurrentTextureView();
        back_buffer_view.release();

        if (self.pass) |pass| {
            pass.end();
            pass.release();
        } else {
            return error.PassDoesNotExist;
        }

        if (self.encoder) |encoder| {
            const commands = encoder.finish(null);
            gctx.submit(&.{commands});

            if (gctx.present() == .swap_chain_resized) {
                self.updateDepthTexture();
            }

            encoder.release();
        } else {
            return error.EncoderDoesNotExist;
        }
    }

    pub fn deinit(self: *Renderer, allocator: std.mem.Allocator) void {
        self.gctx.destroy(allocator);
    }

    fn updateDepthTexture(self: *Renderer) void {
        // Release old depth texture.
        self.gctx.releaseResource(self.depth_texture_view);
        self.gctx.destroyResource(self.depth_texture);

        // Create a new depth texture to match the new window size.
        const depth = createDepthTexture(self.gctx);
        self.depth_texture = depth.texture;
        self.depth_texture_view = depth.view;
    }

    fn createDepthTexture(gctx: *zgpu.GraphicsContext) struct {
        texture: zgpu.TextureHandle,
        view: zgpu.TextureViewHandle,
    } {
        const texture = gctx.createTexture(.{
            .usage = .{ .render_attachment = true },
            .dimension = .tdim_2d,
            .size = .{
                .width = gctx.swapchain_descriptor.width,
                .height = gctx.swapchain_descriptor.height,
                .depth_or_array_layers = 1,
            },
            .format = .depth32_float,
            .mip_level_count = 1,
            .sample_count = 1,
        });
        const view = gctx.createTextureView(texture, .{});
        return .{ .texture = texture, .view = view };
    }
};
