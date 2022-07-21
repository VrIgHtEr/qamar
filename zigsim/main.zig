const Lua = @import("lua.zig").Lua;

const std = @import("std");
const Digisim = @import("digisim.zig").Digisim;
const components = @import("./tree/component.zig").components;
const process = std.process;
const io = std.io;
const stdout = io.getStdOut().writer();

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var args = try process.argsAlloc(allocator);
    defer process.argsFree(allocator, args);
    for (args[1..]) |arg| {
        try stdout.print("{s}\n", .{arg});
    }

    var sim = try Digisim.init(allocator);
    defer sim.deinit();
    try sim.runLuaSetup();
    sim.traceAllPorts();
    _ = try sim.step();
    _ = try sim.step();
    _ = try sim.step();
    return 0;
}
