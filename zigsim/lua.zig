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

    fn upvalueindex(x: c_int) c_int {
        return -10002 - x;
    }

    fn getInstance(L: ?State) *Digisim {
        const v = c.lua_touserdata(L orelse unreachable, upvalueindex(1));
        return @intToPtr(*Digisim, @ptrToInt(v));
    }

    fn lua_version(L: ?State) callconv(.C) c_int {
        getInstance(L).lua.pushlstring("0.1.0");
        return 1;
    }

    fn lua_createcomponent(L: ?State) callconv(.C) c_int {
        const digisim = getInstance(L);
        const lua = &digisim.lua;
        const args = lua.gettop();
        if (args < 1) {
            lua.pushlstring("invalid number of arguments passed to createcomponent");
            lua.err();
        }
        if (!lua.isstring(-1)) {
            lua.pushlstring("first argument to createcomponent was not a string");
            lua.err();
        }
        const str = lua.tolstring(-1);
        const id = digisim.addComponent(str) catch ({
            lua.pushlstring("failed to create component");
            lua.err();
            return 0;
        });
        lua.pushnumber(@bitCast(f64, id));
        return 1;
    }

    pub fn init(digisim: *Digisim) Error!Lua {
        var self: @This() = undefined;
        self.digisim = digisim;
        self.L = c.luaL_newstate() orelse return Error.CannotInitialize;
        errdefer c.lua_close(self.L);
        c.luaL_openlibs(self.L);
        self.newtable();
        self.pushlstring("version");
        self.pushlightuserdata(digisim);
        self.pushcclosure(lua_version, 1);
        self.settable(-3);
        self.pushlstring("createcomponent");
        self.pushlightuserdata(digisim);
        self.pushcclosure(lua_createcomponent, 1);
        self.settable(-3);
        self.setglobal("digisim");
        return self;
    }

    pub fn err(self: *@This()) void {
        _ = c.lua_error(self.L);
    }

    pub fn gettop(self: *@This()) c_int {
        return c.lua_gettop(self.L);
    }

    pub fn settable(self: *@This(), index: c_int) void {
        c.lua_settable(self.L, index);
    }

    pub fn pushlightuserdata(self: *@This(), p: *anyopaque) void {
        c.lua_pushlightuserdata(self.L, p);
    }

    pub fn newtable(self: *@This()) void {
        c.lua_newtable(self.L);
    }

    pub fn pushcclosure(self: *@This(), func: LuaFunc, vals: c_int) void {
        c.lua_pushcclosure(self.L, func, vals);
    }

    pub fn pushnumber(self: *@This(), num: f64) void {
        c.lua_pushnumber(self.L, num);
    }

    pub fn pushcfunction(self: *@This(), func: LuaFunc) void {
        c.lua_pushcfunction(self.L, func);
    }

    pub fn deinit(self: *@This()) void {
        c.lua_close(self.L);
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

    pub fn tolstring(self: *@This(), pos: c_int) []const u8 {
        var len: usize = 0;
        const str = c.lua_tolstring(self.L, pos, &len);
        return str[0..len];
    }

    pub fn rawset(self: *@This(), pos: c_int) void {
        c.lua_rawset(self.L, pos);
    }

    fn prependLuaPath(self: *@This(), prefix: []const u8) !void {
        self.getglobal("package");
        self.pushstring("path");
        self.gettable(-2);
        if (self.isstring(-1)) {
            const path = self.tolstring(-1);
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
