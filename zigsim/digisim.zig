const t = @import("types.zig");
const Component = @import("sim/component.zig").Component;
const Port = @import("sim/port.zig").Port;
const stringIntern = @import("stringIntern.zig");
const std = @import("std");

pub const Digisim = struct {
    allocator: t.Allocator,
    id: t.Id = 0,
    components: t.HashMap(t.Id, Component),
    strings: stringIntern.StringIntern,
    pub fn init(allocator: t.Allocator) @This() {
        var self: @This() = undefined;
        self.allocator = allocator;
        self.id = 0;
        self.strings = stringIntern.StringIntern.init(allocator);
        self.components = t.HashMap(t.Id, Component).init(allocator);
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

    pub fn addComponent(self: *@This(), name: []const u8) !t.Id {
        if (name.len == 0) return error.DigisimInvalidComponentName;
        if (std.mem.indexOf(u8, name, ".")) |_| return error.DigisimInvalidComponentName;
        const interned_name = try self.strings.ref(name);
        errdefer self.strings.unref(interned_name);
        var i = self.components.iterator();
        while (i.next()) |entry| {
            if (entry.value_ptr.name.ptr == interned_name.ptr) {
                return error.DigisimDuplicateComponentName;
            }
        }
        var comp = try Component.init(self, interned_name);
        errdefer comp.deinit(self);
        try self.components.put(comp.id, comp);
        return comp.id;
    }

    pub fn getPort(self: *@This(), name: []const u8) !?*Port {
        if (std.mem.lastIndexOf(u8, name, ".")) |index| {
            var port_name = name[index + 1 ..];
            if (port_name.len == 0) return error.DigisimInvalidPortName;
            if (self.strings.get(port_name)) |n| {
                port_name = n;
            } else return null;

            var comp: ?*Component = null;
            var name_chain = name[0..index];
            while (name_chain.len > 0) {
                var pname: []const u8 = undefined;
                if (std.mem.indexOf(u8, name_chain, ".")) |idx| {
                    pname = name_chain[0..idx];
                    name_chain = name_chain[idx + 1 ..];
                } else {
                    pname = name_chain;
                    name_chain = name_chain[0..0];
                }
                if (pname.len == 0) return error.DigisimInvalidComponentName;
                if (self.strings.get(pname)) |n| {
                    pname = n;
                } else return null;
                if (comp) |c| {
                    if (c.findComponentByName(self, pname)) |x| {
                        comp = x;
                    } else return null;
                } else {
                    if (self.findComponentByName(self, pname)) |c| {
                        comp = c;
                    } else return null;
                }
            }
            if (comp) |c| {
                if (c.findPortByName(self, port_name)) |p| {
                    return p;
                } else return null;
            } else return null;
        } else return null;
    }
};
