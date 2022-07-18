const std = @import("std");
const Digisim = @import("../digisim.zig").Digisim;
const Pin = @import("pin.zig").Pin;
const ArrayList = std.ArrayList;
const HashMap = std.AutoArrayHashMap(usize, *Pin);

pub const Net = struct {
    id: usize,
    pins: HashMap,

    pub fn init(digisim: *Digisim) !@This() {
        var self: @This() = undefined;
        self.id = digisim.nextId();
        self.pins = HashMap.init(digisim.allocator);
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

    pub fn isDriven(self: *@This()) bool {
        var i = self.pins.iterator();
        while (i.next()) |e| {
            if (!e.value_ptr.*.input)
                return true;
        }
        return false;
    }

    pub fn deinit(self: *@This()) void {
        self.pins.deinit();
    }
};
