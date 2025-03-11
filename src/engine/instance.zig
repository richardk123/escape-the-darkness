const std = @import("std");

const DEFAULT_INSTANCE_COUNT: u32 = 500;

pub const Instance = struct {
    position: [3]f32,
    rotation: [4]f32,
    scale: [3]f32,
};

pub const Instances = struct {
    allocator: std.mem.Allocator,
    instances: std.AutoHashMap(usize, std.ArrayList(Instance)),

    pub fn init(allocator: std.mem.Allocator) Instances {
        return Instances{ .allocator = allocator, .instances = std.AutoHashMap(usize, std.ArrayList(Instance)) };
    }

    pub fn add(self: *Instances, mesh_id: usize, instance: Instance) usize {
        const list = self.instances.getPtr(mesh_id) orelse blk: {
            const new_list = std.ArrayList(Instance).init(self.allocator);
            new_list.ensureTotalCapacity(DEFAULT_INSTANCE_COUNT);
            self.instances.put(mesh_id, new_list) catch unreachable;
            break :blk new_list;
        };
        list.append(instance) catch unreachable;

        return list.items.len - 1;
    }

    pub fn remove(self: *Instances, mesh_id: usize, instance_id: usize) void {
        const list = self.instances.getPtr(mesh_id) orelse unreachable;
        list.orderedRemove(instance_id);
    }

    pub fn deinit(self: *Instances) void {
        const it = self.instances.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.instances.deinit();
    }
};
