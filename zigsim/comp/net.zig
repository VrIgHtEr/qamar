const std = @import("std");
const Allocator = std.mem.Allocator;
const Component = @import("component.zig").Component;
const Port = @import("port.zig").Port;

pub const Net = struct {
    sensitivitylist: ?[]*Component,
    tracelist: ?[]*Port,

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        if (self.sensitivitylist) |x| allocator.free(x);
        if (self.tracelist) |x| allocator.free(x);
    }
};
