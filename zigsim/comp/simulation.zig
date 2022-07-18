const std = @import("std");
const Allocator = std.mem.Allocator;
const Component = @import("component.zig").Component;
const Port = @import("port.zig").Port;
const Pin = @import("pin.zig").Pin;
const Net = @import("net.zig").Net;
const Digisim = @import("../digisim.zig").Digisim;

pub const Simulation = struct {
    digisim: *Digisim,
    allocator: Allocator,
    nets: []Net,
    components: []Component,
    ports: []Port,
    dirty: std.AutoHashMap(*Component, void),

    pub fn init(digisim: *Digisim, numNets: []Net, numComponents: []Component, numPorts: []Port) !*@This() {
        const self = try digisim.allocator.create(@This());
        errdefer digisim.allocator.destroy(self);
        self.digisim = digisim;
        self.nets = numNets;
        self.components = numComponents;
        self.ports = numPorts;
        self.dirty = @TypeOf(self.dirty).init(digisim.allocator);
        return self;
    }

    pub fn deinit(self: *@This()) void {
        self.dirty.deinit();
        for (self.components) |*p| p.deinit(self.digisim.allocator);
        self.digisim.allocator.free(self.components);
        for (self.nets) |*p| p.deinit(self.digisim.allocator);
        self.digisim.allocator.free(self.nets);
        for (self.ports) |*p| p.deinit(self.digisim);
        self.digisim.allocator.free(self.ports);
        self.digisim.allocator.destroy(self);
    }

    pub fn step(self: *@This()) bool {
        var iter = self.dirty.iterator();
        while (iter.next()) |e| {
            const component = e.key_ptr;
            _ = component;
        }
        return self.dirty.count() == 0;
    }
};