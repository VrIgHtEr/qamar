const std = @import("std");
const Allocator = std.mem.Allocator;
const Component = @import("comp/component.zig").Component;
const Port = @import("comp/port.zig").Port;
const Pin = @import("comp/pin.zig").Pin;
const Net = @import("comp/net.zig").Net;
const Digisim = @import("digisim.zig").Digisim;

pub const Simulation = struct {
    digisim: *Digisim,
    allocator: Allocator,
    nets: []Net,
    components: []Component,
    ports: []Port,
    dirty: std.AutoHashMap(*Component, void),
    nextdirty: std.AutoHashMap(*Component, void),

    pub fn init(digisim: *Digisim, numNets: []Net, numComponents: []Component, numPorts: []Port) !*@This() {
        const self = try digisim.allocator.create(@This());
        errdefer digisim.allocator.destroy(self);
        self.digisim = digisim;
        self.nets = numNets;
        self.components = numComponents;
        self.ports = numPorts;
        self.dirty = @TypeOf(self.dirty).init(digisim.allocator);
        self.nextdirty = @TypeOf(self.nextdirty).init(digisim.allocator);
        for (numComponents) |*c| try self.dirty.put(c, .{});
        return self;
    }

    pub fn deinit(self: *@This()) void {
        self.nextdirty.deinit();
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
            //generate inputs
            //run handler
            //for each output pin
            //    if output has changed mark net as dirty
            _ = component;
        }
        //mark all components in the sensitivity lists of dirty nets as dirty
        //resolve all dirty nets
        //trace values
        const t = self.dirty;
        self.dirty = self.nextdirty;
        self.nextdirty = t;
        self.nextdirty.clearRetainingCapacity();
        return self.dirty.count() == 0;
    }
};
