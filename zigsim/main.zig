const Lua = @import("lua.zig").Lua;

const std = @import("std");
const digisim = @import("digisim.zig");
const t = @import("types.zig");
const components = @import("./sim/component.zig").components;

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
        try cmp.setHandler(components.nand_h);
        _ = try cmp.addPort("input", true, 0, 1, true);
        _ = try cmp.addPort("output", false, 0, 1, true);
        try cmp.connect("output", "input");
        try sim.compile();
        return 0;
    }
    return 1;
}
