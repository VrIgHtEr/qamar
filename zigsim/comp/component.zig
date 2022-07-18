const std = @import("std");
const Allocator = std.mem.Allocator;
const Port = @import("port.zig").Port;

pub const Component = struct {
    ports: []*Port,

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        allocator.free(self.ports);
    }
};
