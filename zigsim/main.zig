const std = @import("std");
const digisim = @import("digisim.zig");
const t = @import("types.zig");

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var sim = digisim.Digisim.init(allocator);
    defer sim.deinit();

    const x = t.Signal.uninitialized;
    const y = x.resolve(t.Signal.z);
    _ = y;
    return 0;
}
