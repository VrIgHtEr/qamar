const std = @import("std");
const Allocator = std.mem.Allocator;
const Port = @import("port.zig").Port;
const Signal = @import("../signal.zig").Signal;
const Handler = @import("../simulation.zig").Handler;

pub const Component = struct {
    inports: []*Port,
    outports: []*Port,
    numInputs: usize,
    numOutputs: usize,
    handler: Handler,
    data: usize,

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        allocator.free(self.inports);
        allocator.free(self.outports);
    }
};
