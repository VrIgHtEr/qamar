const std = @import("std");

pub const Id = usize;
pub const Allocator = std.mem.Allocator;
pub const ArrayList = std.ArrayList;
pub const HashMap = std.AutoArrayHashMap;

pub const Signal = enum(u8) {
    uninitialized = 0,
    unknown = 1,
    low = 2,
    high = 3,
    z = 4,
    weak = 5,
    weaklow = 6,
    weakhigh = 7,

    pub fn resolve(self: @This(), other: @This()) @This() {
        return restable[@enumToInt(self) * @typeInfo(@This()).Enum.fields.len + @enumToInt(other)];
    }
};

pub const restable = [_]Signal{ Signal.uninitialized, Signal.unknown, Signal.low, Signal.high, Signal.z, Signal.weak, Signal.weaklow, Signal.weakhigh, Signal.unknown, Signal.unknown, Signal.unknown, Signal.unknown, Signal.unknown, Signal.unknown, Signal.unknown, Signal.unknown, Signal.low, Signal.unknown, Signal.low, Signal.unknown, Signal.low, Signal.low, Signal.low, Signal.low, Signal.high, Signal.unknown, Signal.unknown, Signal.high, Signal.high, Signal.high, Signal.high, Signal.high, Signal.z, Signal.unknown, Signal.low, Signal.high, Signal.z, Signal.weak, Signal.weaklow, Signal.weakhigh, Signal.weak, Signal.unknown, Signal.low, Signal.high, Signal.weak, Signal.weak, Signal.weak, Signal.weak, Signal.weaklow, Signal.unknown, Signal.low, Signal.high, Signal.weaklow, Signal.weak, Signal.weaklow, Signal.weak, Signal.weakhigh, Signal.unknown, Signal.low, Signal.high, Signal.weakhigh, Signal.weak, Signal.weak, Signal.weakhigh };

comptime {
    if (restable.len != std.math.pow(usize, @typeInfo(Signal).Enum.fields.len, 2)) unreachable;
}
