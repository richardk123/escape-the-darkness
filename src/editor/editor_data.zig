const std = @import("std");
const mesh = @import("../engine/mesh.zig");
const expect = std.testing.expect;

pub const EditorData = struct {
    tiles: std.ArrayList(Tile),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) EditorData {
        return .{
            .tiles = std.ArrayList(Tile).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn addTile(self: *EditorData, name: []const u8) void {
        const name_copy = self.allocator.dupe(u8, name) catch @panic("Cannot copy tile name");
        const tile = Tile.init(self.allocator, name_copy);
        self.tiles.append(tile) catch @panic("Cannot add tile");
    }

    pub fn toJson(self: *EditorData) ![]u8 {
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();

        var json_obj = std.json.Value{
            .object = std.json.ObjectMap.init(arena.allocator()),
        };

        var tiles_array = std.json.Value{
            .array = std.json.Array.init(arena.allocator()),
        };

        for (self.tiles.items) |*tile| {
            const tile_json = try tile.toJsonValue(arena.allocator());
            try tiles_array.array.append(tile_json);
        }

        try json_obj.object.put("tiles", tiles_array);

        var string = std.ArrayList(u8).init(self.allocator);
        errdefer string.deinit();

        try std.json.stringify(json_obj, .{}, string.writer());

        return string.toOwnedSlice();
    }

    pub fn fromJson(json_str: []u8, allocator: std.mem.Allocator) !EditorData {
        var data = EditorData.init(allocator);
        errdefer data.deinit();

        var parsed = try std.json.parseFromSlice(std.json.Value, allocator, json_str, .{});
        defer parsed.deinit();

        const root = parsed.value;
        if (root.object.get("tiles")) |tiles_json| {
            if (tiles_json == .array) {
                for (tiles_json.array.items) |tile_json| {
                    const tile = try Tile.fromJsonValue(tile_json, allocator);
                    try data.tiles.append(tile);
                }
            }
        }

        return data;
    }

    pub fn deinit(self: *EditorData) void {
        for (self.tiles.items) |*tile| {
            tile.deinit();
        }
        self.tiles.deinit();
    }
};

pub const Tile = struct {
    name: []u8,
    level_min: u32 = 0,
    level_max: u32 = 0,
    objects: std.ArrayList(Object),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, name: []u8) Tile {
        return Tile{
            .name = name,
            .objects = std.ArrayList(Object).init(allocator),
            .allocator = allocator,
        };
    }

    fn toJsonValue(self: *Tile, arena_allocator: std.mem.Allocator) !std.json.Value {
        var json_obj = std.json.Value{
            .object = std.json.ObjectMap.init(arena_allocator),
        };

        try json_obj.object.put("name", .{ .string = try arena_allocator.dupe(u8, self.name) });
        try json_obj.object.put("level_min", .{ .integer = self.level_min });
        try json_obj.object.put("level_max", .{ .integer = self.level_max });

        var objects_array = std.json.Value{
            .array = std.json.Array.init(arena_allocator),
        };

        for (self.objects.items) |*obj| {
            const obj_json = try obj.toJsonValue(arena_allocator);
            try objects_array.array.append(obj_json);
        }

        try json_obj.object.put("objects", objects_array);
        return json_obj;
    }

    fn fromJsonValue(value: std.json.Value, allocator: std.mem.Allocator) !Tile {
        var tile = Tile.init(allocator, try allocator.dupe(u8, "")); // Initialize with empty name first

        if (value.object.get("name")) |name| {
            if (name == .string) {
                // Free the empty name we created
                allocator.free(tile.name);
                // Set the actual name
                tile.name = try allocator.dupe(u8, name.string);
            }
        }

        if (value.object.get("level_min")) |level_min| {
            if (level_min == .integer) {
                tile.level_min = @intCast(level_min.integer);
            }
        }

        if (value.object.get("level_max")) |level_max| {
            if (level_max == .integer) {
                tile.level_max = @intCast(level_max.integer);
            }
        }

        if (value.object.get("objects")) |objects_json| {
            if (objects_json == .array) {
                for (objects_json.array.items) |obj_json| {
                    const obj = try Object.fromJsonValue(obj_json);
                    try tile.objects.append(obj);
                }
            }
        }

        return tile;
    }

    pub fn addObject(self: *Tile) !void {
        try self.objects.append(Object{});
    }

    pub fn deinit(self: *Tile) void {
        self.allocator.free(self.name);
        self.objects.deinit();
    }
};

pub const Object = struct {
    model_type: ObjectType = .cube,
    position: [3]f32 = .{ 0, 0, 0 },
    rotation: [3]f32 = .{ 0, 0, 0 },

    pub fn toJsonValue(self: *Object, arena_allocator: std.mem.Allocator) !std.json.Value {
        var json_obj = std.json.Value{
            .object = std.json.ObjectMap.init(arena_allocator),
        };

        // Store model_type as an integer
        try json_obj.object.put("model_type", .{ .string = @tagName(self.model_type) });

        // Create position array
        var pos_array = std.json.Value{
            .array = std.json.Array.init(arena_allocator),
        };

        for (self.position) |pos| {
            try pos_array.array.append(.{ .float = pos });
        }
        try json_obj.object.put("position", pos_array);

        // Create rotation array
        var rot_array = std.json.Value{
            .array = std.json.Array.init(arena_allocator),
        };

        for (self.rotation) |rot| {
            try rot_array.array.append(.{ .float = rot });
        }
        try json_obj.object.put("rotation", rot_array);

        return json_obj;
    }

    fn fromJsonValue(value: std.json.Value) !Object {
        var obj = Object{};

        if (value.object.get("model_type")) |model_type| {
            if (model_type == .string) {
                // Convert string to enum
                if (std.meta.stringToEnum(ObjectType, model_type.string)) |object_type| {
                    obj.model_type = object_type;
                }
            }
        }

        if (value.object.get("position")) |position| {
            if (position == .array and position.array.items.len == 3) {
                for (position.array.items, 0..) |pos, i| {
                    if (pos == .float) {
                        obj.position[i] = @floatCast(pos.float);
                    }
                }
            }
        }

        if (value.object.get("rotation")) |rotation| {
            if (rotation == .array and rotation.array.items.len == 3) {
                for (rotation.array.items, 0..) |rot, i| {
                    if (rot == .float) {
                        obj.rotation[i] = @floatCast(rot.float);
                    }
                }
            }
        }

        return obj;
    }
};

pub const ObjectType = enum {
    cube,
    cube_long,
    sphere,
};

test "serialize" {
    var editor_data = EditorData.init(std.testing.allocator);
    defer editor_data.deinit();

    editor_data.addTile("tile1");

    var tile = &editor_data.tiles.items[0];
    try tile.addObject();
    var object = &tile.objects.items[0];
    object.model_type = .cube_long;
    object.position = .{ 1, 1, 1 };
    object.rotation = .{ 2, 2, 2 };

    const json_string = try editor_data.toJson();
    defer std.testing.allocator.free(json_string);

    try expect(std.mem.eql(u8, json_string,
        \\{"tiles":[{"name":"tile1","level_min":0,"level_max":0,"objects":[{"model_type":"cube_long","position":[1e0,1e0,1e0],"rotation":[2e0,2e0,2e0]}]}]}
    ));
}

test "deserialize" {
    // Create a JSON string representing editor data
    const json_string =
        \\{"tiles":[{"name":"test_tile","level_min":3,"level_max":5,"objects":[{"model_type":"sphere","position":[1.5,2.5,3.5],"rotation":[0.1,0.2,0.3]}]}]}
    ;

    // Parse the JSON string into EditorData
    var editor_data = try EditorData.fromJson(@constCast(json_string), std.testing.allocator);
    defer editor_data.deinit();

    // Verify the parsed data
    try expect(editor_data.tiles.items.len == 1);

    const tile = editor_data.tiles.items[0];
    try expect(std.mem.eql(u8, tile.name, "test_tile"));
    try expect(tile.level_min == 3);
    try expect(tile.level_max == 5);
    try expect(tile.objects.items.len == 1);

    const object = tile.objects.items[0];
    try expect(object.model_type == .sphere);
    try expect(object.position[0] == 1.5);
    try expect(object.position[1] == 2.5);
    try expect(object.position[2] == 3.5);
    try expect(object.rotation[0] == 0.1);
    try expect(object.rotation[1] == 0.2);
    try expect(object.rotation[2] == 0.3);
}
