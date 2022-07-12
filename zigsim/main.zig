const c = @cImport({
    // See https://github.com/ziglang/zig/issues/515
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cDefine("NULL", "(0)");
    @cInclude("luajit-2.1/lua.h");
    @cInclude("luajit-2.1/lauxlib.h");
    @cInclude("luajit-2.1/lualib.h");
});

const std = @import("std");
const digisim = @import("digisim.zig");
const t = @import("types.zig");

pub fn main() !u8 {

    //var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //const allocator = gpa.allocator();
    var L: *c.lua_State = c.luaL_newstate() orelse return error.CannotInitializeLua;
    defer c.lua_close(L);
    c.luaL_openlibs(L);

    var status = c.luaL_loadstring(L, "print('hello world!')");
    if (status != 0) {
        std.debug.print("Couldn't load file {s}", .{c.lua_tostring(L, -1)});
        c.lua_pop(L, -1);
        return error.FailedToLoadScript;
    }

    var result = c.lua_pcall(L, 0, c.LUA_MULTRET, 0);
    if (result != 0) {
        std.debug.print("Failed to run script {s}", .{c.lua_tostring(L, -1)});
        c.lua_pop(L, -1);
        return error.FailedToRunScript;
    }

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
