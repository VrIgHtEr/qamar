const t = @import("../types.zig");
const Pin = @import("pin.zig").Pin;
const Digisim = @import("../digisim.zig").Digisim;
const Err = @import("../digisim.zig").Error;

pub const Port = struct {
    id: t.Id,
    pins: t.HashMap(t.Id, Pin),
    name: []const u8,
    input: bool,
    start: usize,
    end: usize,

    pub fn init(digisim: *Digisim, name: []const u8, input: bool, start: usize, end: usize) !@This() {
        var self: @This() = undefined;
        if (end <= start) return Err.InvalidPortSize;
        self.id = digisim.nextId();
        self.input = input;
        self.pins = t.HashMap(t.Id, Pin).init(digisim.allocator);
        self.start = start;
        self.end = end;
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

    pub fn width(self: *@This()) usize {
        return self.end - self.start;
    }
};
