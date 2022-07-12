const std = @import("std");
const digisim = @import("digisim.zig");
const t = @import("types.zig");

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var sim = try digisim.Digisim.init(allocator);
    defer sim.deinit();

    _ = try sim.addComponent("core");
    const comp = try sim.getComponent("core");
    if (comp) |c| {
        _ = try c.addPort(&sim, "input", true, 0, 1);
        try c.connect(&sim, "input[0]", "input[1]");
        return 0;
    }
    return 1;
}
