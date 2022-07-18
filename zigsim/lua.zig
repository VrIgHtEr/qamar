const std = @import("std");
const stdout = std.io.getStdOut().writer();
const c = @cImport({
    // See https://github.com/ziglang/zig/issues/515
    @cDefine("_NO_CRT_STDIO_INLINE", "1");
    @cDefine("NULL", "(0)");
    @cInclude("lua.h");
    @cInclude("lauxlib.h");
    @cInclude("lualib.h");
});

pub const State = *c.lua_State;
pub const Error = error{ cannotInitialize, loadStringFailed, scriptError };
pub const Lua = struct {
    L: State,

    pub fn init() Error!Lua {
        var ret: @This() = undefined;
        ret.L = c.luaL_newstate() orelse return Error.cannotInitialize;
        return ret;
    }

    pub fn deinit(self: *@This()) void {
        c.lua_close(self.L);
    }

    pub fn openlibs(self: *@This()) void {
        c.luaL_openlibs(self.L);
    }

    pub fn loadstring(self: *@This(), string: [:0]const u8) Error!void {
        var status = c.luaL_loadstring(self.L, string.ptr);
        if (status != 0) {
            stdout.print("Couldn't load string: {s}", .{c.lua_tostring(self.L, -1)}) catch ({});
            c.lua_pop(self.L, -1);
            return Error.loadStringFailed;
        }
    }

    pub fn execute(self: *@This(), script: [:0]const u8) Error!void {
        try self.loadstring(script);

        var result = c.lua_pcall(self.L, 0, c.LUA_MULTRET, 0);
        if (result != 0) {
            stdout.print("Failed to run script: {s}", .{c.lua_tostring(self.L, -1)}) catch ({});
            c.lua_pop(self.L, -1);
            return Error.scriptError;
        }
    }
};
