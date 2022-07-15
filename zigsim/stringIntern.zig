const std = @import("std");
const Allocator = std.mem.Allocator;

pub const StringIntern = struct {
    allocator: Allocator,
    strings: std.StringHashMap(usize),

    pub fn init(allocator: Allocator) @This() {
        var ret: @This() = .{ .allocator = allocator, .strings = std.StringHashMap(usize).init(allocator) };
        return ret;
    }

    pub fn get(self: *@This(), value: []const u8) ?[]const u8 {
        if (self.strings.getKeyPtr(value)) |e| {
            return e.*;
        }
        return null;
    }

    pub fn ref(self: *@This(), value: []const u8) ![]const u8 {
        var entry: *usize = undefined;
        var key: []const u8 = undefined;
        if (self.strings.getEntry(value)) |e| {
            entry = e.value_ptr;
            key = e.key_ptr.*;
        } else {
            var k = try self.allocator.alloc(u8, value.len);
            std.mem.copy(u8, k, value);
            try self.strings.put(k, 0);
            entry = self.strings.getPtr(k) orelse unreachable;
            key = k;
        }
        entry.* += 1;
        return key;
    }

    pub fn unref(self: *@This(), value: []const u8) void {
        if (self.strings.getEntry(value)) |e| {
            e.value_ptr.* -= 1;
            if (e.value_ptr.* == 0) {
                var key = e.key_ptr.*;
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
