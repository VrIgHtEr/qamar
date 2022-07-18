const std = @import("std");
const Allocator = std.mem.Allocator;
const Port = @import("port.zig").Port;

pub const Component = struct {
    inports: []*Port,
    outports: []*Port,
    numInputs: usize,
    numOutputs: usize,

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        allocator.free(self.inports);
        allocator.free(self.outports);
    }
};
