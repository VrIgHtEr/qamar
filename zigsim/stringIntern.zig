const std = @import("std");
const Allocator = std.mem.Allocator;

const Entry = struct {
    refcount: usize = 0,
    value: std.ArrayList(u8),

    pub fn init(allocator: Allocator, value: []const u8) !@This() {
        var ret = .{ .value = std.ArrayList(u8).init(allocator) };
        errdefer ret.value.deinit();
        try ret.value.ensureTotalCapacityPrecise(value.len);
        try ret.value.appendSlice(value);
        return ret;
    }

    pub fn deinit(self: *@This()) void {
        self.value.deinit();
    }
};

pub const StringIntern = struct {
    allocator: Allocator,
    strings: std.StringHashMap(Entry),

    pub fn init(allocator: Allocator) @This() {
        var ret: @This() = .{ .allocator = allocator, .strings = std.StringHashMap(Entry).init(allocator) };
        return ret;
    }

    pub fn get(self: *@This(), value: []const u8) ?[]const u8 {
        if (self.strings.getPtr(value)) |e| {
            return e.value.items;
        }
        return null;
    }

    pub fn ref(self: *@This(), value: []const u8) ![]const u8 {
        std.debug.print("  REF: {s}", .{value});
        errdefer std.debug.print("\n", .{});
        var entry: *Entry = undefined;
        if (self.strings.getPtr(value)) |e| {
            entry = e;
        } else {
            var t = try Entry.init(self.allocator, value);
            errdefer t.deinit();
            try self.strings.put(value, t);
            entry = self.strings.getPtr(value) orelse unreachable;
        }
        entry.refcount += 1;
        std.debug.print(" : {s} : {}\n", .{ entry.value.items, entry.refcount });
        return entry.value.items;
    }

    pub fn unref(self: *@This(), value: []const u8) void {
        std.debug.print("UNREF: {s}", .{value});
        errdefer std.debug.print("\n", .{});
        if (self.strings.getPtr(value)) |e| {
            e.refcount -= 1;
            std.debug.print(" : {}\n", .{e.refcount});
            if (e.refcount == 0) {
                _ = self.strings.remove(value);
            }
        } else unreachable;
    }

    pub fn deinit(self: *@This()) void {
        var i = self.strings.iterator();
        while (i.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.strings.deinit();
    }
};
