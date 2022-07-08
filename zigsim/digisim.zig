const t = @import("types.zig");
const component = @import("sim/component.zig");

pub const Digisim = struct {
    allocator: t.Allocator,
    id: t.Id = 0,
    components: component.ComponentHash,
    pub fn init(allocator: t.Allocator) @This() {
        var self: @This() = undefined;
        self.allocator = allocator;
        self.id = 0;
        self.components = component.ComponentHash.init(allocator);
        return self;
    }

    pub fn deinit(self: *@This()) void {
        var i = self.components.iterator();
        while (i.next()) |c| {
            c.value_ptr.deinit();
        }
        self.components.deinit();
    }
};
