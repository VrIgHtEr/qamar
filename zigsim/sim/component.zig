const t = @import("../types.zig");
const port = @import("port.zig");
const Digisim = @import("../digisim.zig").Digisim;

pub const Component = struct {
    id: t.Id,
    ports: port.PortHash,
    name: []const u8,

    pub fn init(digisim: *Digisim, name: []const u8) !@This() {
        var self: @This() = undefined;
        self.id = digisim.nextId();
        self.ports = port.PortHash.init(digisim.allocator);
        errdefer self.ports.deinit();
        self.name = name;
        return self;
    }

    pub fn deinit(self: *@This(), digisim: *Digisim) void {
        digisim.strings.unref(self.name);
        var i = self.ports.iterator();
        while (i.next()) |entry| {
            entry.value_ptr.deinit(digisim);
        }
        self.ports.deinit();
    }

    pub fn addPort(self: *@This(), digisim: *Digisim, name: []const u8) !t.Id {
        const interned_name = digisim.strings.ref(name);
        errdefer digisim.strings.unref(interned_name);
        var p = port.Port.init(digisim, interned_name);
        errdefer p.deinit();
        try self.ports.put(p.id, p);
        return p.id;
    }
};

pub const ComponentHash = t.HashMap(t.Id, Component);
