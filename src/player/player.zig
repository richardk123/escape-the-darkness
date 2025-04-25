const Engine = @import("../engine/engine.zig").Engine;
const MaterialType = @import("../engine/material.zig").MaterialType;
const MeshType = @import("../engine/mesh.zig").MeshType;
const MeshInstance = @import("../engine/mesh_renderer.zig").MeshInstance;
const MeshRenderer = @import("../engine/mesh_renderer.zig").MeshRenderer;
const Flares = @import("flare.zig").Flares;

pub const Player = struct {
    engine: *Engine,
    ship_renderer: *MeshRenderer,
    ship_id: u32,
    flares: Flares,

    pub fn init(engine: *Engine) !Player {
        const ship_renderer = try engine.addMeshRenderer(MaterialType.echolocation, MeshType.sphere);
        const ship_id = ship_renderer.addInstance(.{ 0.0, 2.0, -10.0 }, null, null);
        const flares = try Flares.init(engine);

        return .{
            .engine = engine,
            .ship_renderer = ship_renderer,
            .ship_id = ship_id,
            .flares = flares,
        };
    }

    pub fn update(self: *Player) void {
        const dt = self.engine.renderer.gctx.stats.delta_time;
        const ship = self.ship_renderer.getInstance(self.ship_id) orelse @panic("cannot find ship");
        self.flares.update(ship.position, dt);
    }

    pub fn deinit(self: *Player) void {
        self.flares.deinit();
    }
};
