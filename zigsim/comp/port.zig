const std = @import("std");
const Pin = @import("pin.zig").Pin;
const Digisim = @import("../digisim.zig").Digisim;

pub const Port = struct {
    pins: []Pin,
    alias: ?[]const u8,

    pub fn deinit(self: *@This(), digisim: *Digisim) void {
        digisim.allocator.free(self.pins);
        if (self.alias) |a| digisim.strings.unref(a);
    }
};
