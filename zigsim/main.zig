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

    var ref = try sim.strings.ref("Hello");
    std.debug.print("{any} - {any}\n", .{ ref.len, @ptrToInt(ref.ptr) });
    ref = try sim.strings.ref("World");
    std.debug.print("{any} - {any}\n", .{ ref.len, @ptrToInt(ref.ptr) });
    ref = try sim.strings.ref("Hello");
    std.debug.print("{any} - {any}\n", .{ ref.len, @ptrToInt(ref.ptr) });

    sim.strings.unref("Hello");
    sim.strings.unref("World");
    sim.strings.unref("Hello");

    _ = try sim.addComponent("core");
    return 0;
}
