const t = @import("../types.zig");
const pin = @import("pin.zig");
const Digisim = @import("../digisim.zig").Digisim;

pub const Port = struct {
    id: t.Id,
    pins: pin.PinHash,
    name: []const u8,

    pub fn init(digisim: *Digisim, name: []const u8) !@This() {
        var self: @This() = undefined;
        self.id = digisim.nextId();
        self.pins = pin.PinHash.init(digisim.allocator);
        errdefer self.pins.deinit();
        self.name = name;
        return self;
    }
    pub fn deinit(self: *@This(), digisim: *Digisim) void {
        digisim.strings.unref(self.name);
        var i = self.pins.iterator();
        while (i.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.pins.deinit();
    }
};

pub const PortHash = t.HashMap(t.Id, Port);
