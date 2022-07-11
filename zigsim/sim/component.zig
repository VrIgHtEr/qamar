const std = @import("std");
const t = @import("../types.zig");
const Port = @import("port.zig").Port;
const digi = @import("../digisim.zig");
const Digisim = digi.Digisim;
const Err = digi.Error;

pub const Component = struct {
    id: t.Id,
    ports: t.HashMap(t.Id, void),
    components: t.HashMap(t.Id, void),
    name: []const u8,

    pub fn init(digisim: *Digisim, name: []const u8) !@This() {
        var self: @This() = undefined;
        self.id = digisim.nextId();
        self.ports = t.HashMap(t.Id, void).init(digisim.allocator);
        self.components = t.HashMap(t.Id, void).init(digisim.allocator);
        self.name = name;
        return self;
    }

    pub fn findComponent(self: *@This(), id: t.Id) ?*Component {
        return self.components.getPtr(id);
    }

    fn findComponentByName(self: *@This(), digisim: *Digisim, name: []const u8) ?*Component {
        var i = self.components.iterator();
        while (i.next()) |e| {
            const entry = digisim.components.getPtr(e.key_ptr.*) orelse unreachable;
            if (entry.name.ptr == name.ptr) return entry;
        }
        return null;
    }

    pub fn deinit(self: *@This(), digisim: *Digisim) void {
        var j = self.components.iterator();
        while (j.next()) |e| {
            const entry = digisim.components.getPtr(e.key_ptr.*) orelse unreachable;
            entry.deinit(digisim);
        }
        var i = self.ports.iterator();
        while (i.next()) |e| {
            const entry = digisim.ports.getPtr(e.key_ptr.*) orelse unreachable;
            entry.deinit(digisim);
        }
        self.ports.deinit();
        digisim.strings.unref(self.name);
        _ = digisim.components.swapRemove(self.id);
    }

    pub fn findPort(self: *@This(), id: t.Id) ?*Port {
        return self.ports.getPtr(id);
    }

    fn findPortByName(self: *@This(), digisim: *Digisim, name: []const u8) ?*Port {
        var i = self.ports.iterator();
        while (i.next()) |e| {
            const entry = digisim.ports.getPtr(e.key_ptr.*) orelse unreachable;
            if (entry.name.ptr == name.ptr) return entry;
        }
        return null;
    }

    pub fn addPort(self: *@This(), digisim: *Digisim, name: []const u8, input: bool, start: usize, end: usize) !t.Id {
        if (name.len == 0) return Err.InvalidPortName;
        if (std.mem.indexOf(u8, name, ".")) |_| return Err.InvalidPortName;
        const interned_name = try digisim.strings.ref(name);
        errdefer digisim.strings.unref(interned_name);
        var i = self.ports.iterator();
        while (i.next()) |e| {
            const entry = digisim.ports.getPtr(e.key_ptr.*) orelse unreachable;
            if (entry.name.ptr == interned_name.ptr) return Err.DuplicatePortName;
        }
        var p = try Port.init(digisim, interned_name, input, start, end);
        errdefer p.deinit(digisim);
        try self.ports.put(p.id, {});
        errdefer _ = self.ports.swapRemove(p.id);
        try digisim.ports.put(p.id, p);
        return p.id;
    }

    pub fn addComponent(self: *@This(), digisim: *Digisim, name: []const u8) !t.Id {
        if (name.len == 0) return Err.InvalidComponentName;
        if (std.mem.indexOf(u8, name, ".")) |_| return Err.InvalidComponentName;
        const interned_name = try digisim.strings.ref(name);
        errdefer digisim.strings.unref(interned_name);
        var i = self.components.iterator();
        while (i.next()) |e| {
            const entry = digisim.components.getPtr(e.key_ptr.*) orelse unreachable;
            if (entry.name.ptr == interned_name.ptr) {
                return Err.DuplicateComponentName;
            }
        }
        var comp = try Component.init(digisim, interned_name);
        errdefer comp.deinit(digisim);
        try self.components.put(comp.id, {});
        errdefer _ = self.components.swapRemove(comp.id);
        try digisim.components.put(comp.id, comp);
        return comp.id;
    }

    pub fn getComponent(self: *@This(), digisim: *Digisim, name: []const u8) Err!?*Component {
        var name_chain = name;
        var comp: ?*Component = null;
        if (name_chain.len == 0) return Err.InvalidComponentName;
        while (name_chain.len > 0) {
            var pname: []const u8 = undefined;
            if (std.mem.indexOf(u8, name_chain, ".")) |idx| {
                pname = name_chain[0..idx];
                name_chain = name_chain[idx + 1 ..];
            } else {
                pname = name_chain;
                name_chain = name_chain[0..0];
            }
            if (pname.len == 0) return Err.InvalidComponentName;
            if (digisim.strings.get(pname)) |n| {
                pname = n;
            } else return null;
            if (comp) |c| {
                if (c.findComponentByName(digisim, pname)) |x| {
                    comp = x;
                } else return null;
            } else {
                if (self.findComponentByName(digisim, pname)) |c| {
                    comp = c;
                } else return null;
            }
        }
        return comp;
    }

    pub fn getPort(self: *@This(), digisim: *Digisim, name: []const u8) Err!?*Port {
        if (std.mem.lastIndexOf(u8, name, ".")) |index| {
            const port_name = name[index + 1 ..];
            if (port_name.len == 0) return Err.InvalidPortName;
            if (digisim.strings.get(port_name)) |n| {
                if (try self.getComponent(digisim, name[0..index])) |c| {
                    if (c.findPortByName(digisim, n)) |p| {
                        return p;
                    }
                }
            }
        } else {
            if (name.len == 0) return Err.InvalidPortName;
            if (digisim.strings.get(name)) |n| {
                return self.findPortByName(digisim, n);
            }
        }

        return null;
    }
};
