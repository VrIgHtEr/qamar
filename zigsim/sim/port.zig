const t = @import("../types.zig");
const std = @import("std");
const Pin = @import("pin.zig").Pin;
const Digisim = @import("../digisim.zig").Digisim;
const Err = @import("../digisim.zig").Error;

pub const Port = struct {
    id: t.Id,
    pins: std.ArrayList(Pin),
    name: []const u8,
    input: bool,
    start: usize,
    end: usize,

    pub fn init(digisim: *Digisim, name: []const u8, input: bool, start: usize, end: usize) !@This() {
        var self: @This() = undefined;
        if (end < start) return Err.InvalidPortSize;
        self.id = digisim.nextId();
        self.input = input;
        self.start = start;
        self.end = end;
        self.name = name;
        self.pins = std.ArrayList(Pin).init(digisim.allocator);
        errdefer self.pins.deinit();
        try self.pins.ensureTotalCapacityPrecise(self.width());
        const w = self.width();
        var i: usize = 0;
        errdefer ({
            while (i > 0) {
                i -= 1;
                self.pins.items[i].deinit();
            }
        });
        while (i < w) : (i += 1) {
            var pin = try Pin.init(digisim);
            errdefer pin.deinit();
            try self.pins.append(pin);
        }
        return self;
    }

    pub fn deinit(self: *@This(), digisim: *Digisim) void {
        digisim.strings.unref(self.name);
        for (self.pins.items) |_, index| {
            self.pins.items[index].deinit();
        }
    }

    pub fn width(self: *@This()) usize {
        return self.end - self.start + 1;
    }
};
