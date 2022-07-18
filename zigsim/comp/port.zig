const std = @import("std");
const Pin = @import("pin.zig").Pin;
const Digisim = @import("../digisim.zig").Digisim;
const Signal = @import("../signal.zig").Signal;

pub const Port = struct {
    pins: []Pin,
    alias: ?[]const u8,

    pub fn deinit(self: *@This(), digisim: *Digisim) void {
        digisim.allocator.free(self.pins);
        if (self.alias) |a| digisim.strings.unref(a);
    }

    pub fn trace(self: *@This()) void {
        if (self.pins.len > 1) {} else {
            const value = Signal.tovcd(self.pins[0].net.value);
            if (value == Signal.z) {
                std.debug.print("z{s}\n", .{self.alias orelse unreachable});
            } else if (value == Signal.unknown) {
                std.debug.print("x{s}\n", .{self.alias orelse unreachable});
            } else if (value == Signal.low) {
                std.debug.print("0{s}\n", .{self.alias orelse unreachable});
            } else {
                std.debug.print("1{s}\n", .{self.alias orelse unreachable});
            }
        }
    }
};
