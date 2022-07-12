const t = @import("../types.zig");
const std = @import("std");
const Digisim = @import("../digisim.zig").Digisim;
const Pin = @import("pin.zig").Pin;
const ArrayList = std.ArrayList;

pub const Net = struct {
    id: t.Id,
    pins: t.HashMap(t.Id, *Pin),

    pub fn init(digisim: *Digisim) !@This() {
        var self: @This() = undefined;
        self.id = digisim.nextId();
        self.pins = t.HashMap(t.Id, *Pin).init(digisim.allocator);
        return self;
    }

    pub fn merge(self: *@This(), digisim: *Digisim, other: *@This()) !void {
        var i = self.pins.iterator();
        while (i.next()) |entry| {
            entry.value_ptr.*.net = other.id;
            errdefer entry.value_ptr.*.net = self.id;
            try other.pins.put(entry.key_ptr.*, entry.value_ptr.*);
        }
        const id = self.id;
        self.deinit();
        _ = digisim.nets.swapRemove(id);
    }

    pub fn deinit(self: *@This()) void {
        self.pins.deinit();
    }
};
