const std = @import("std");
const Allocator = std.mem.Allocator;
const Component = @import("component.zig").Component;
const Port = @import("port.zig").Port;
const Pin = @import("pin.zig").Pin;
const Signal = @import("../signal.zig").Signal;

pub const Net = struct {
    sensitivitylist: ?[]*Component,
    tracelist: ?[]*Port,
    driverlist: ?[]*Pin,
    value: Signal,

    pub fn deinit(self: *@This(), allocator: Allocator) void {
        if (self.sensitivitylist) |x| allocator.free(x);
        if (self.tracelist) |x| allocator.free(x);
        if (self.driverlist) |x| allocator.free(x);
    }
};
