const t = @import("../types.zig");
const std = @import("std");
const Digisim = @import("../digisim.zig").Digisim;
const Pin = @import("pin.zig").Pin;
const ArrayList = std.ArrayList;

pub const Net = struct {
    id: t.Id,
    pins: ArrayList(Pin),

    pub fn init(digisim: *Digisim) !@This() {
        var self: @This() = undefined;
        self.id = digisim.nextId();
        self.pins = ArrayList(Pin).init(digisim.allocator);
        return self;
    }

    pub fn deinit(self: *@This()) void {
        self.pins.deinit();
    }
};
