const t = @import("../types.zig");
const Pin = @import("pin.zig").Pin;
const Digisim = @import("../digisim.zig").Digisim;

pub const Port = struct {
    id: t.Id,
    pins: t.HashMap(t.Id, Pin),
    name: []const u8,

    pub fn init(digisim: *Digisim, name: []const u8) !@This() {
        var self: @This() = undefined;
        self.id = digisim.nextId();
        self.pins = t.HashMap(t.Id, Pin).init(digisim.allocator);
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
