const std = @import("std");
const Pin = @import("pin.zig").Pin;
const Digisim = @import("../digisim.zig").Digisim;
const Signal = @import("../signal.zig").Signal;
const stdout = std.io.getStdOut().writer();

pub const Port = struct {
    pins: []Pin,
    alias: ?[]const u8,

    pub fn deinit(self: *@This(), digisim: *Digisim) void {
        digisim.allocator.free(self.pins);
        if (self.alias) |a| digisim.strings.unref(a);
    }

    pub fn trace(self: *@This()) void {
        if (self.pins.len > 1) {
            stdout.print("b", .{}) catch ({});
            var i = self.pins.len;
            while (i > 0) {
                i -= 1;
                const value = Signal.tovcd(self.pins[0].net.value);
                if (value == Signal.z) {
                    stdout.print("z", .{}) catch ({});
                } else if (value == Signal.unknown) {
                    stdout.print("x", .{}) catch ({});
                } else if (value == Signal.low) {
                    stdout.print("0", .{}) catch ({});
                } else {
                    stdout.print("1", .{}) catch ({});
                }
            }
            stdout.print(" {s}\n", .{self.alias orelse unreachable}) catch ({});
        } else {
            const value = Signal.tovcd(self.pins[0].net.value);
            if (value == Signal.z) {
                stdout.print("z{s}\n", .{self.alias orelse unreachable}) catch ({});
            } else if (value == Signal.unknown) {
                stdout.print("x{s}\n", .{self.alias orelse unreachable}) catch ({});
            } else if (value == Signal.low) {
                stdout.print("0{s}\n", .{self.alias orelse unreachable}) catch ({});
            } else {
                stdout.print("1{s}\n", .{self.alias orelse unreachable}) catch ({});
            }
        }
    }
};
