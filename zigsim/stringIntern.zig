const std = @import("std");
const Allocator = std.mem.Allocator;

const Entry = struct {
    refcount: usize = 0,
    value: []const u8,

    pub fn init(value: []const u8) @This() {
        return @This(){ .value = value };
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
            return e.value;
        }
        return null;
    }

    pub fn ref(self: *@This(), value: []const u8) ![]const u8 {
        var entry: *Entry = undefined;
        if (self.strings.getPtr(value)) |e| {
            entry = e;
        } else {
            var key = try self.allocator.alloc(u8, value.len);
            std.mem.copy(u8, key, value);
            var t = Entry.init(key);
            try self.strings.put(key, t);
            entry = self.strings.getPtr(value) orelse unreachable;
        }
        entry.refcount += 1;
        return entry.value;
    }

    pub fn unref(self: *@This(), value: []const u8) void {
        if (self.strings.getPtr(value)) |e| {
            e.refcount -= 1;
            if (e.refcount == 0) {
                const key = e.value;
                _ = self.strings.remove(key);
                self.allocator.free(key);
            }
        } else unreachable;
    }

    pub fn deinit(self: *@This()) void {
        var i = self.strings.iterator();
        while (i.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.strings.deinit();
    }
};
