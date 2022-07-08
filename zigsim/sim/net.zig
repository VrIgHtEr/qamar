const t = @import("../types.zig");

pub const Net = struct {
    id: t.Id,

    pub fn init(allocator: t.Allocator, id: t.Id) @This() {
        _ = allocator;
        var self: @This() = undefined;
        self.id = id;
        return self;
    }

    pub fn deinit(self: *@This()) void {
        _ = self;
    }
};

pub const NetHash = t.HashMap(t.Id, Net);
