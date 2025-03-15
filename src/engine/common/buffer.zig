const zgpu = @import("zgpu");
const wgpu = zgpu.wgpu;

pub fn GPUBuffer(comptime T: type) type {
    return struct {
        gpu_buffer: zgpu.BufferHandle,
        total_number: u32,
        gctx: *zgpu.GraphicsContext,

        const Self = @This();

        pub fn init(gctx: *zgpu.GraphicsContext, usage: wgpu.BufferUsage, total_number: u32) Self {
            const buffer = gctx.createBuffer(.{
                .usage = usage,
                .size = total_number * @sizeOf(T),
            });

            return .{
                .gpu_buffer = buffer,
                .total_number = total_number,
                .gctx = gctx,
            };
        }

        pub fn write(self: *const GPUBuffer(T), data: []const T) void {
            self.gctx.queue.writeBuffer(self.gctx.lookupResource(self.gpu_buffer).?, 0, T, data);
        }
    };
}
