const t = @import("../types.zig");
const Digisim = @import("../digisim.zig").Digisim;

pub const Pin = struct {
    id: t.Id,
    net: t.Id,

    pub fn init(digisim: *Digisim) !@This() {
        var self: @This() = .{ .id = digisim.nextId(), .net = 0 };
        return self;
    }

    pub fn deinit(self: *@This(), digisim: *Digisim) void {
        if (self.net != 0) {
            const net = digisim.nets.getPtr(self.net) orelse unreachable;
            _ = net.pins.swapRemove(self.id);
            if (net.pins.count() == 0) {
                const id = net.id;
                net.deinit();
                _ = digisim.nets.swapRemove(id);
            }
        }
    }
};
