const t = @import("../types.zig");
const port = @import("port.zig");

pub const Component = struct {
    id: t.Id,
    ports: port.PortHash,

    pub fn init(allocator: t.Allocator, id: t.Id) @This() {
        var self: @This() = undefined;
        self.id = id;
        self.ports = port.PortHash.init(allocator);
        return self;
    }
    pub fn deinit(self: *@This()) void {
        var i = self.ports.iterator();
        while (i.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.ports.deinit();
    }
};

pub const ComponentHash = t.HashMap(t.Id, Component);
