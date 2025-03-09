const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;

const Renderer = @import("renderer.zig").Renderer;

pub const Frame = struct {
    renderer: *Renderer,
    encoder: wgpu.CommandEncoder,
    back_buffer_view: wgpu.TextureView,
    pass: ?wgpu.RenderPassEncoder,

    pub fn init(renderer: *Renderer) Frame {
        const gctx = renderer.gctx;

        const back_buffer_view = gctx.swapchain.getCurrentTextureView();

        const encoder = gctx.device.createCommandEncoder(null);

        return Frame{
            .renderer = renderer,
            .encoder = encoder,
            .back_buffer_view = back_buffer_view,
            .pass = null,
        };
    }

    pub fn beginRenderPass(self: *Frame) !wgpu.RenderPassEncoder {
        const gctx = self.renderer.gctx;

        const depth_view = gctx.lookupResource(self.renderer.depth_texture_view) orelse return error.DepthViewNotExist;

        const color_attachments = [_]wgpu.RenderPassColorAttachment{.{
            .view = self.back_buffer_view,
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

        const pass = self.encoder.beginRenderPass(render_pass_info);
        self.pass = pass;
        return pass;
    }

    pub fn end(self: *Frame) !void {
        const gctx = self.renderer.gctx;

        self.back_buffer_view.release();

        if (self.pass) |pass| {
            pass.end();
            pass.release();
        } else {
            return error.PassDoesNotExist;
        }

        const commands = self.encoder.finish(null);

        gctx.submit(&.{commands});

        if (gctx.present() == .swap_chain_resized) {
            self.renderer.updateDepthTexture();
        }

        self.encoder.release();
    }
};
