const std = @import("std");
const Allocator = std.mem.Allocator;
const Pin = @import("pin.zig").Pin;

pub const Port = struct {
    pins: []Pin,

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        allocator.free(self.pins);
    }
};
