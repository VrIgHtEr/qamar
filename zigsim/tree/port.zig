const std = @import("std");
const Pin = @import("pin.zig").Pin;
const Digisim = @import("../digisim.zig").Digisim;
const Net = @import("net.zig").Net;
const Err = @import("../digisim.zig").Error;

pub const Port = struct {
    digisim: *Digisim,
    id: usize,
    pins: []Pin,
    name: []const u8,
    alias: ?[]const u8,
    input: bool,
    start: usize,
    end: usize,
    trace: bool,

    pub fn init(digisim: *Digisim, name: []const u8, input: bool, start: usize, end: usize, trace: bool) !@This() {
        var self: @This() = undefined;
        self.digisim = digisim;
        if (end < start) return Err.InvalidPortSize;
        self.id = digisim.nextId();
        self.input = input;
        self.start = start;
        self.end = end;
        self.name = name;
        self.alias = null;
        const w = self.width();
        self.pins = try digisim.allocator.alloc(Pin, w);
        self.trace = trace;
        errdefer digisim.allocator.free(self.pins);
        var i: usize = 0;
        errdefer ({
            while (i > 0) {
                i -= 1;
                self.pins[i].deinit();
            }
        });
        while (i < w) : (i += 1) {
            self.pins[i] = try Pin.init(digisim, input, self.id);
            errdefer self.pins[i].deinit();
            var net = try Net.init(digisim);
            errdefer net.deinit();
            try net.pins.put(self.pins[i].id, &self.pins[i]);
            errdefer _ = net.pins.swapRemove(self.pins[i].id);
            try digisim.nets.put(net.id, net);
            self.pins[i].net = net.id;
        }
        return self;
    }

    pub fn deinit(self: *@This()) void {
        for (self.pins) |_, index| {
            self.pins[index].deinit();
        }
        self.digisim.allocator.free(self.pins);
        self.digisim.strings.unref(self.name);
        if (self.alias) |a| self.digisim.strings.unref(a);
        _ = self.digisim.ports.swapRemove(self.id);
    }

    pub fn width(self: *@This()) usize {
        return self.end - self.start + 1;
    }
};
