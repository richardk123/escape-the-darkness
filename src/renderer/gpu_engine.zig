const std = @import("std");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const zglfw = @import("zglfw");
const zm = @import("zmath");
const math = std.math;
const zgui = @import("zgui");

const TextureView = wgpu.TextureView;
const CommandEncoder = wgpu.CommandEncoder;

const Meshes = @import("mesh_loader.zig").Meshes;
const Mesh = @import("mesh_loader.zig").Mesh;
const Vertex = @import("mesh_loader.zig").Vertex;
const EcholocationProgram = @import("echolocation/echolocation.zig").EcholocationProgram;
const GridFloorProgram = @import("grid_floor/grid_floor.zig").GridFloorProgram;

pub const RenderParams = struct {
    gctx: *zgpu.GraphicsContext,
    meshes: *Meshes,
    back_buffer_view: TextureView,
    encoder: CommandEncoder,
    depth_texture_view: zgpu.TextureViewHandle,
};

pub const GPUEngine = struct {
    gctx: *zgpu.GraphicsContext,
    depth_texture: zgpu.TextureHandle,
    depth_texture_view: zgpu.TextureViewHandle,
    echolocation_program: EcholocationProgram,
    grid_gloor_program: GridFloorProgram,

    pub fn init(allocator: std.mem.Allocator, window: *zglfw.Window, meshes: *Meshes) !GPUEngine {
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

        const echolocation_program = try EcholocationProgram.init(gctx, meshes);
        const grid_floor_program = try GridFloorProgram.init(allocator, gctx);
        // Create a depth texture and its 'view'.
        const depth = createDepthTexture(gctx);

        return GPUEngine{
            .gctx = gctx,
            .echolocation_program = echolocation_program,
            .grid_gloor_program = grid_floor_program,
            .depth_texture = depth.texture,
            .depth_texture_view = depth.view,
        };
    }

    pub fn deinit(self: *GPUEngine, allocator: std.mem.Allocator) void {
        self.gctx.destroy(allocator);
    }

    pub fn draw(self: *GPUEngine, meshes: *Meshes) void {
        const gctx = self.gctx;

        const back_buffer_view = gctx.swapchain.getCurrentTextureView();
        defer back_buffer_view.release();

        const commands = commands: {
            const encoder = gctx.device.createCommandEncoder(null);
            defer encoder.release();

            const renderParams = RenderParams{
                .gctx = gctx,
                .meshes = meshes,
                .back_buffer_view = back_buffer_view,
                .encoder = encoder,
                .depth_texture_view = self.depth_texture_view,
            };

            self.echolocation_program.render(renderParams);
            self.grid_gloor_program.render(renderParams);
            // gui pass
            {
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

            break :commands encoder.finish(null);
        };
        defer commands.release();

        gctx.submit(&.{commands});

        if (gctx.present() == .swap_chain_resized) {
            // Release old depth texture.
            gctx.releaseResource(self.depth_texture_view);
            gctx.destroyResource(self.depth_texture);

            // Create a new depth texture to match the new window size.
            const depth = createDepthTexture(gctx);
            self.depth_texture = depth.texture;
            self.depth_texture_view = depth.view;
        }
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
