const t = @import("../types.zig");
const pin = @import("pin.zig");

pub const Port = struct {
    id: t.Id,
    pins: pin.PinHash,

    pub fn init(allocator: t.Allocator, id: t.Id) @This() {
        var self: @This() = undefined;
        self.id = id;
        self.pins = pin.PinHash.init(allocator);
        return self;
    }
    pub fn deinit(self: *@This()) void {
        var i = self.pins.iterator();
        while (i.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.pins.deinit();
    }
};

pub const PortHash = t.HashMap(t.Id, Port);
