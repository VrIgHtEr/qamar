const Lua = @import("lua.zig").Lua;

const std = @import("std");
const digisim = @import("digisim.zig");
const t = @import("types.zig");

pub fn main() !u8 {
    var lua = try Lua.init();
    defer lua.deinit();
    lua.openlibs();

    try lua.execute(@embedFile("main.lua"));

    var sim = try digisim.Digisim.init(std.heap.c_allocator);
    defer sim.deinit();

    _ = try sim.addComponent("core");
    const comp = try sim.getComponent("core");
    if (comp) |cmp| {
        _ = try cmp.addPort(&sim, "input", true, 0, 1);
        try cmp.connect(&sim, "input[0]", "input[1]");
        return 0;
    }
    return 1;
}
