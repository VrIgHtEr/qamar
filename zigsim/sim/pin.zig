const t = @import("../types.zig");
const Digisim = @import("../digisim.zig").Digisim;

pub const Pin = struct {
    id: t.Id,

    pub fn init(digisim: *Digisim) !@This() {
        var self: @This() = .{
            .id = digisim.nextId(),
        };
        return self;
    }

    pub fn deinit(self: *@This()) void {
        _ = self;
    }
};
