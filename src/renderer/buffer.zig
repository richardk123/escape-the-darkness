const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;

pub fn GPUBuffer(comptime T: type) type {
    return struct {
        gpu_buffer: zgpu.BufferHandle,
        total_number: u32,

        const Self = @This();

        pub fn init(gctx: *zgpu.GraphicsContext, usage: wgpu.BufferUsage, total_number: u32) Self {
            const buffer = gctx.createBuffer(.{
                .usage = usage,
                .size = total_number * @sizeOf(T),
            });

            return .{
                .gpu_buffer = buffer,
                .total_number = total_number,
            };
        }

        pub fn write(self: *const GPUBuffer(T), gctx: *zgpu.GraphicsContext, data: []const T) void {
            gctx.queue.writeBuffer(gctx.lookupResource(self.gpu_buffer).?, 0, T, data);
        }
    };
}
