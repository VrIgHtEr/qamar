const std = @import("std");
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

    pub fn collapse(self: @This()) Signal {
        if (self == Signal.high or self == Signal.weakhigh) return Signal.high;
        return Signal.low;
    }

    pub fn tovcd(self: @This()) Signal {
        if (self == Signal.low or self == Signal.weaklow) return Signal.low;
        if (self == Signal.high or self == Signal.weakhigh) return Signal.high;
        if (self == Signal.z) return Signal.z;
        return Signal.unknown;
    }
};

const restable = [_]Signal{ Signal.uninitialized, Signal.unknown, Signal.low, Signal.high, Signal.z, Signal.weak, Signal.weaklow, Signal.weakhigh, Signal.unknown, Signal.unknown, Signal.unknown, Signal.unknown, Signal.unknown, Signal.unknown, Signal.unknown, Signal.unknown, Signal.low, Signal.unknown, Signal.low, Signal.unknown, Signal.low, Signal.low, Signal.low, Signal.low, Signal.high, Signal.unknown, Signal.unknown, Signal.high, Signal.high, Signal.high, Signal.high, Signal.high, Signal.z, Signal.unknown, Signal.low, Signal.high, Signal.z, Signal.weak, Signal.weaklow, Signal.weakhigh, Signal.weak, Signal.unknown, Signal.low, Signal.high, Signal.weak, Signal.weak, Signal.weak, Signal.weak, Signal.weaklow, Signal.unknown, Signal.low, Signal.high, Signal.weaklow, Signal.weak, Signal.weaklow, Signal.weak, Signal.weakhigh, Signal.unknown, Signal.low, Signal.high, Signal.weakhigh, Signal.weak, Signal.weak, Signal.weakhigh };

comptime {
    if (restable.len != std.math.pow(usize, @typeInfo(Signal).Enum.fields.len, 2)) unreachable;
}
