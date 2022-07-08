const t = @import("types.zig");
const component = @import("sim/component.zig");
const stringIntern = @import("stringIntern.zig");

pub const Digisim = struct {
    allocator: t.Allocator,
    id: t.Id = 0,
    components: component.ComponentHash,
    strings: stringIntern.StringIntern,
    pub fn init(allocator: t.Allocator) @This() {
        var self: @This() = undefined;
        self.allocator = allocator;
        self.id = 0;
        self.strings = stringIntern.StringIntern.init(allocator);
        self.components = component.ComponentHash.init(allocator);
        return self;
    }

    pub fn deinit(self: *@This()) void {
        var i = self.components.iterator();
        while (i.next()) |c| {
            c.value_ptr.deinit(self);
        }
        self.components.deinit();
        self.strings.deinit();
    }

    pub fn nextId(self: *@This()) t.Id {
        self.id += 1;
        return self.id;
    }

    pub fn addComponent(self: *@This(), name: []const u8) !t.Id {
        const interned_name = try self.strings.ref(name);
        errdefer self.strings.unref(interned_name);
        var comp = try component.Component.init(self, interned_name);
        errdefer comp.deinit(self);
        try self.components.put(comp.id, comp);
        return comp.id;
    }
};
