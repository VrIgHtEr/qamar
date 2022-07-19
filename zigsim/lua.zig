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
const LuaFunc = fn (?State) callconv(.C) c_int;
const Digisim = @import("digisim.zig").Digisim;
pub const Error = error{ CannotInitialize, LoadStringFailed, ScriptError };
pub const Lua = struct {
    digisim: *Digisim,
    L: State,

    pub fn init(digisim: *Digisim) Error!Lua {
        var ret: @This() = undefined;
        ret.digisim = digisim;
        ret.L = c.luaL_newstate() orelse return Error.CannotInitialize;
        return ret;
    }

    pub fn pushcfunction(self: *@This(), func: LuaFunc) void {
        c.lua_pushcfunction(self.L, func);
    }

    pub fn pushglobalcfunction(self: *@This(), name: [:0]const u8, func: LuaFunc) void {
        self.pushcfunction(func);
        self.setglobal(name);
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
            return Error.LoadStringFailed;
        }
    }

    pub fn execute(self: *@This(), script: [:0]const u8) Error!void {
        try self.loadstring(script);

        var result = c.lua_pcall(self.L, 0, c.LUA_MULTRET, 0);
        if (result != 0) {
            stdout.print("Failed to run script: {s}", .{c.lua_tostring(self.L, -1)}) catch ({});
            c.lua_pop(self.L, -1);
            return Error.ScriptError;
        }
        c.lua_pop(self.L, -1);
    }

    pub fn pushnil(self: *@This()) void {
        c.lua_pushnil(self.L);
    }

    pub fn setglobal(self: *@This(), glob: [:0]const u8) void {
        c.lua_setglobal(self.L, glob);
    }

    pub fn getglobal(self: *@This(), glob: [:0]const u8) void {
        c.lua_getglobal(self.L, glob);
    }

    pub fn pushstring(self: *@This(), glob: [:0]const u8) void {
        c.lua_pushstring(self.L, glob);
    }

    pub fn pushlstring(self: *@This(), glob: []const u8) void {
        c.lua_pushlstring(self.L, glob.ptr, glob.len);
    }

    pub fn gettable(self: *@This(), pos: c_int) void {
        c.lua_gettable(self.L, pos);
    }

    pub fn isstring(self: *@This(), pos: c_int) bool {
        return c.lua_isstring(self.L, pos) != 0;
    }

    pub fn pop(self: *@This(), pos: c_int) void {
        c.lua_pop(self.L, pos);
    }

    pub fn tolstring(self: *@This(), pos: c_int, len: *usize) [:0]const u8 {
        return std.mem.span(c.lua_tolstring(self.L, pos, len));
    }

    pub fn rawset(self: *@This(), pos: c_int) void {
        c.lua_rawset(self.L, pos);
    }

    fn prependLuaPath(self: *@This(), prefix: []const u8) !void {
        self.getglobal("package");
        self.pushstring("path");
        self.gettable(-2);
        if (self.isstring(-1)) {
            var len: usize = undefined;
            const path = self.tolstring(-1, &len);
            const concatenated = try std.mem.concat(std.heap.c_allocator, u8, &[_][]const u8{ prefix, ";", path });
            defer std.heap.c_allocator.free(concatenated);
            self.pop(1);
            self.pushstring("path");
            self.pushlstring(concatenated);
            self.rawset(-3);
            self.pop(1);
        } else {
            self.pop(2);
        }
    }
    pub fn setupenv(self: *@This(), root: [:0]const u8) !void {
        {
            const len = std.mem.len(root);
            var str = try std.fs.path.join(std.heap.c_allocator, &[_][]const u8{ root[0..len], "?/init.lua" });
            defer std.heap.c_allocator.free(str);
            try self.prependLuaPath(str);
        }
        {
            const len = std.mem.len(root);
            var str = try std.fs.path.join(std.heap.c_allocator, &[_][]const u8{ root[0..len], "?.lua" });
            defer std.heap.c_allocator.free(str);
            try self.prependLuaPath(str);
        }
        self.pushnil();
        self.setglobal("package");
    }
};
