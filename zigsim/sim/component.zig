const std = @import("std");
const t = @import("../types.zig");
const Port = @import("port.zig").Port;
const Digisim = @import("../digisim.zig").Digisim;

pub const Component = struct {
    id: t.Id,
    ports: t.HashMap(t.Id, Port),
    components: t.HashMap(t.Id, Component),
    name: []const u8,

    pub fn init(digisim: *Digisim, name: []const u8) !@This() {
        var self: @This() = undefined;
        self.id = digisim.nextId();
        self.ports = t.HashMap(t.Id, Port).init(digisim.allocator);
        self.components = t.HashMap(t.Id, Component).init(digisim.allocator);
        self.name = name;
        return self;
    }

    pub fn findComponent(self: *@This(), id: t.Id) ?*Component {
        return self.components.getPtr(id);
    }

    pub fn findComponentByName(self: *@This(), digisim: *Digisim, name: []const u8) ?*Component {
        if (digisim.strings.get(name)) |interned_name| {
            var i = self.components.iterator();
            while (i.next()) |entry| {
                if (entry.value_ptr.name.ptr == interned_name.ptr) return entry.value_ptr;
            }
        }
        return null;
    }

    pub fn deinit(self: *@This(), digisim: *Digisim) void {
        var i = self.ports.iterator();
        while (i.next()) |entry| {
            entry.value_ptr.deinit(digisim);
        }
        self.ports.deinit();
        var j = self.components.iterator();
        while (j.next()) |entry| {
            entry.value_ptr.deinit(digisim);
        }
        digisim.strings.unref(self.name);
    }

    pub fn findPort(self: *@This(), id: t.Id) ?*Port {
        return self.ports.getPtr(id);
    }

    pub fn findPortByName(self: *@This(), digisim: *Digisim, name: []const u8) ?*Port {
        if (digisim.strings.get(name)) |interned_name| {
            var i = self.ports.iterator();
            while (i.next()) |entry| {
                if (entry.value_ptr.name.ptr == interned_name.ptr) return entry.value_ptr;
            }
        }
        return null;
    }

    pub fn addPort(self: *@This(), digisim: *Digisim, name: []const u8) !t.Id {
        if (name.len == 0) return error.DigisimInvalidPortName;
        if (std.mem.indexOf(u8, name, ".")) |_| return error.DigisimInvalidPortName;
        const interned_name = digisim.strings.ref(name);
        errdefer digisim.strings.unref(interned_name);
        var i = self.ports.iterator();
        while (i.next()) |entry| {
            if (entry.value_ptr.name.ptr == interned_name.ptr) return error.DigisimDuplicatePortName;
        }
        var p = Port.init(digisim, interned_name);
        errdefer p.deinit();
        try self.ports.put(p.id, p);
        return p.id;
    }

    pub fn addComponent(self: *@This(), digisim: *Digisim, name: []const u8) !t.Id {
        if (name.len == 0) return error.DigisimInvalidComponentName;
        if (std.mem.indexOf(u8, name, ".")) |_| return error.DigisimInvalidComponentName;
        const interned_name = try digisim.strings.ref(name);
        errdefer digisim.strings.unref(interned_name);
        var i = self.components.iterator();
        while (i.next()) |entry| {
            if (entry.value_ptr.name.ptr == interned_name.ptr) {
                return error.DigisimDuplicateComponentName;
            }
        }
        var comp = try Component.init(digisim, interned_name);
        errdefer comp.deinit(digisim);
        try self.components.put(comp.id, comp);
        return comp.id;
    }
};
