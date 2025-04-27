const std = @import("std");
const math = std.math;
const zgui = @import("zgui");
const zm = @import("zmath");
const zglfw = @import("zglfw");
const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;
const content_dir = @import("build_options").content_dir;
const mapData = @import("map_data.zig");
const GUIUtils = @import("gui_utils.zig");

const Engine = @import("../engine/engine.zig").Engine;
const mr = @import("../engine/mesh_renderer.zig");

pub const MapEditorGui = struct {
    engine: *Engine,
    map_data: mapData.MapData,
    selected_tile: ?*mapData.Tile = undefined,
    str_gen: GUIUtils.StrGen = GUIUtils.StrGen.init(),

    pub fn init(allocator: std.mem.Allocator, window: *zglfw.Window, engine: *Engine) MapEditorGui {
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

        return MapEditorGui{
            .engine = engine,
            .map_data = mapData.MapData.init(engine.allocator),
        };
    }

    pub fn update(self: *MapEditorGui) !void {
        const gctx = self.engine.renderer.gctx;
        zgui.backend.newFrame(
            gctx.swapchain_descriptor.width,
            gctx.swapchain_descriptor.height,
        );

        const window_height: f32 = @floatFromInt(gctx.swapchain_descriptor.height);
        zgui.setNextWindowPos(.{ .x = 0.0, .y = 0.0 });
        zgui.setNextWindowSize(.{ .w = 800.0, .h = window_height });

        if (zgui.begin("Map editor", .{ .flags = .{} })) {
            zgui.text("FPS: {d:.0}", .{zgui.io.getFramerate()});
            zgui.spacing();

            self.mainButtons();
            zgui.spacing();
            zgui.separator();
            zgui.spacing();

            self.tileControll();
            self.objectsControll();
        }
        zgui.end();

        try self.draw();
    }

    fn mainButtons(self: *MapEditorGui) void {
        if (zgui.button("Save", .{})) {
            self.map_data.save() catch @panic("cannot save map");
        }
        zgui.sameLine(.{});
        if (zgui.button("Load", .{})) {
            const new_map_data = mapData.MapData.load(self.engine.allocator) catch @panic("cannot load map");
            self.map_data.deinit();
            self.map_data = new_map_data;
            self.selected_tile = null;
        }
    }

    fn tileControll(self: *MapEditorGui) void {
        const tile_name = if (self.selected_tile) |tile| tile.name else "Select a tile";
        const tile_preview = self.str_gen.tranform(tile_name);

        if (zgui.beginCombo("tile", .{ .preview_value = tile_preview, .flags = .{} })) {
            for (self.map_data.tiles.items, 0..) |*tile, i| {
                const is_selected = if (self.selected_tile) |selected|
                    std.mem.eql(u8, selected.name, tile.name)
                else
                    false;
                const tile_id = self.str_gen.getId(tile.name, i);
                if (zgui.selectable(tile_id, .{ .selected = is_selected })) {
                    // Update the selected tile when clicked
                    self.selected_tile = tile;
                }

                if (is_selected) {
                    zgui.setItemDefaultFocus();
                }
            }
            zgui.endCombo();
        }
        zgui.sameLine(.{});

        if (zgui.button("Add##tile", .{})) {
            const new_name = self.str_gen.getName("New Tile", self.map_data.tiles.items.len);
            self.map_data.addTile(new_name);
            self.selected_tile = self.map_data.getLastTile();
        }

        if (self.selected_tile) |tile| {
            zgui.text("{s}", .{tile.name});
            GUIUtils.inputU32("min level", &tile.level_min);
            GUIUtils.inputU32("max level", &tile.level_max);
        }
    }

    fn objectsControll(self: *MapEditorGui) void {
        zgui.text("Objects", .{});
        zgui.sameLine(.{});
        if (self.selected_tile) |tile| {
            if (zgui.button("Add##object", .{})) {
                tile.addObject() catch @panic("Cannot add new object to tile");
            }
            for (tile.objects.items, 0..) |*object, i| {
                const object_type_name = std.enums.tagName(mapData.ObjectType, object.model_type) orelse "";
                const preview_val = self.str_gen.tranform(object_type_name);
                const model_name = self.str_gen.getId("Model", i);
                if (zgui.beginCombo(model_name, .{ .preview_value = preview_val, .flags = .{} })) {
                    for (std.enums.values(mapData.ObjectType), 0..) |*obj_type, j| {
                        const is_selected = object.model_type == obj_type.*;
                        const obj_type_name = std.enums.tagName(mapData.ObjectType, obj_type.*) orelse "";
                        const obj_type_id = self.str_gen.getId(obj_type_name, j);
                        if (zgui.selectable(obj_type_id, .{ .selected = is_selected })) {
                            object.model_type = obj_type.*;
                        }

                        if (is_selected) {
                            zgui.setItemDefaultFocus();
                        }
                    }
                    zgui.endCombo();
                }
                const position_id = self.str_gen.getId("Position", i);
                if (zgui.dragFloat3(position_id, .{ .v = &object.position })) {
                    std.debug.print("changed position", .{});
                }
                const rotation_id = self.str_gen.getId("Rotation", i);
                if (zgui.dragFloat3(rotation_id, .{ .v = &object.rotation })) {
                    std.debug.print("changed rotation", .{});
                }
                zgui.separator();
            }
        }
    }

    fn draw(self: *MapEditorGui) !void {
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

    pub fn deinit(self: *MapEditorGui) void {
        zgui.backend.deinit();
        zgui.deinit();
        self.map_data.deinit();
    }
};
