const t = @import("../types.zig");

pub const Pin = struct {
    id: t.Id,
    input: bool,

    pub fn init(allocator: t.Allocator, id: t.Id, input: bool) @This() {
        _ = allocator;
        var self: @This() = .{
            .id = id,
            .input = input,
        };
        return self;
    }

    pub fn deinit(self: *@This()) void {
        _ = self;
    }
};

pub const PinHash = t.HashMap(t.Id, Pin);
