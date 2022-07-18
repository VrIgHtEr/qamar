const std = @import("std");
const Digisim = @import("../digisim.zig").Digisim;

pub const Pin = struct {
    digisim: *Digisim,
    id: usize,
    portid: usize,
    net: usize,
    input: bool,

    pub fn init(digisim: *Digisim, input: bool, portid: usize) !@This() {
        var self: @This() = .{ .digisim = digisim, .id = digisim.nextId(), .net = 0, .input = input, .portid = portid };
        return self;
    }

    pub fn deinit(self: *@This()) void {
        if (self.net != 0) {
            const net = self.digisim.nets.getPtr(self.net) orelse unreachable;
            _ = net.pins.swapRemove(self.id);
            if (net.pins.count() == 0) {
                const id = net.id;
                net.deinit();
                _ = self.digisim.nets.swapRemove(id);
            }
        }
    }
};
