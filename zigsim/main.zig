const Lua = @import("lua.zig").Lua;

const std = @import("std");
const Digisim = @import("digisim.zig").Digisim;
const components = @import("./tree/component.zig").components;

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var lua = try Lua.init();
    defer lua.deinit();
    lua.openlibs();

    try lua.execute(@embedFile("main.lua"));

    var sim = try Digisim.init(allocator);
    defer sim.deinit();

    _ = try sim.addComponent("core");
    const comp = try sim.getComponent("core");
    if (comp) |cmp| {
        try cmp.setHandler(components.nand_h);
        _ = try cmp.addPort("input", true, 0, 1, true);
        _ = try cmp.addPort("output", false, 0, 0, true);
        try cmp.connect("output", "input[0]");
        try cmp.connect("output", "input[1]");
        while (true)
            _ = try sim.step();
        return 0;
    }
    return 1;
}
