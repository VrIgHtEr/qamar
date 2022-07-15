const std = @import("std");
const Allocator = std.mem.Allocator;
const Digisim = @import("digisim.zig").Digisim;

pub const IdGen = struct {
    allocator: Allocator,
    string: []u8 = undefined,

    pub fn init(allocator: Allocator) !@This() {
        var ret: @This() = .{
            .allocator = allocator,
        };
        ret.string = try allocator.alloc(u8, 1);
        errdefer allocator.free(ret.string);
        ret.string[0] = 32;

        return ret;
    }

    pub fn refNewId(self: *@This(), digisim: *Digisim) ![]const u8 {
        self.string[0] += 1;
        var i: usize = 0;
        while (self.string[i] == 127) : (i += 1) {
            self.string[i] = 33;
            if (i == self.string.len - 1) {
                self.string = try self.allocator.realloc(self.string, self.string.len + 1);
            }
            self.string[i + 1] += 1;
        }
        return try digisim.strings.ref(self.string);
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.string);
    }
};
