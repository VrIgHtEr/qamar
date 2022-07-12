const t = @import("types.zig");
const Component = @import("sim/component.zig").Component;
const Port = @import("sim/port.zig").Port;
const Pin = @import("sim/pin.zig").Pin;
const Net = @import("sim/net.zig").Net;
const std = @import("std");
const ArrayList = std.ArrayList;
const stringIntern = @import("stringIntern.zig");
const root_name: []const u8 = "__ROOT__";

pub const Error = error{
    DuplicateComponentName,
    InvalidComponentName,
    DuplicatePortName,
    InvalidPortName,
    InvalidPortSize,
    MismatchingPortWidths,
    PortNotFound,
};

pub const Digisim = struct {
    allocator: t.Allocator,
    id: t.Id = 0,
    root: Component,
    strings: stringIntern.StringIntern,
    components: t.HashMap(t.Id, Component),
    ports: t.HashMap(t.Id, Port),
    nets: t.HashMap(t.Id, Net),
    pub fn init(allocator: t.Allocator) !@This() {
        var self: @This() = undefined;
        self.allocator = allocator;
        self.id = 0;
        self.strings = stringIntern.StringIntern.init(allocator);
        errdefer self.strings.deinit();
        self.components = t.HashMap(t.Id, Component).init(allocator);
        errdefer self.components.deinit();
        self.ports = t.HashMap(t.Id, Port).init(allocator);
        errdefer self.ports.deinit();
        self.nets = t.HashMap(t.Id, Net).init(allocator);
        errdefer self.nets.deinit();
        self.root = try Component.init(&self, try self.strings.ref(root_name));
        return self;
    }

    pub fn deinit(self: *@This()) void {
        self.root.deinit(self);
        self.nets.deinit();
        self.ports.deinit();
        self.components.deinit();
        self.strings.deinit();
    }

    pub fn nextId(self: *@This()) t.Id {
        self.id += 1;
        return self.id;
    }

    pub fn addComponent(self: *@This(), name: []const u8) !t.Id {
        return self.root.addComponent(self, name);
    }

    pub fn getComponent(self: *@This(), name: []const u8) !?*Component {
        return self.root.getComponent(self, name);
    }

    pub fn getPort(self: *@This(), name: []const u8) !?*Port {
        return self.root.getPort(self, name);
    }
};
