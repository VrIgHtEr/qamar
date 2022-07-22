const std = @import("std");
const stdout = std.io.getStdOut().writer();
const Allocator = std.mem.Allocator;
const Component = @import("comp/component.zig").Component;
const Port = @import("comp/port.zig").Port;
const Pin = @import("comp/pin.zig").Pin;
const Net = @import("comp/net.zig").Net;
const Digisim = @import("digisim.zig").Digisim;
const Signal = @import("signal.zig").Signal;

const PQEntry = struct {
    timestamp: usize,
    component: *Component,
    fn compare(_: void, a: PQEntry, b: PQEntry) std.math.Order {
        return std.math.order(a.timestamp, b.timestamp);
    }
};
const Pq = std.PriorityQueue(PQEntry, void, PQEntry.compare);

pub const Handler = fn (usize, []Signal, []Signal, *anyopaque) usize;

pub const Simulation = struct {
    digisim: *Digisim,
    nets: []Net,
    components: []Component,
    ports: []Port,
    dirtynets: std.AutoHashMap(*Net, void),
    dirty: std.AutoHashMap(*Component, void),
    nextdirty: std.AutoHashMap(*Component, void),
    traceports: std.AutoHashMap(*Port, void),
    inputs: []Signal,
    outputs: []Signal,
    timestamp: usize,
    pq: Pq,

    pub fn init(digisim: *Digisim, numNets: []Net, numComponents: []Component, numPorts: []Port) !*@This() {
        const self = try digisim.allocator.create(@This());
        errdefer digisim.allocator.destroy(self);
        self.digisim = digisim;
        self.nets = numNets;
        self.components = numComponents;
        self.ports = numPorts;
        self.timestamp = 0;
        self.dirty = @TypeOf(self.dirty).init(digisim.allocator);
        errdefer self.nextdirty.deinit();
        self.nextdirty = @TypeOf(self.nextdirty).init(digisim.allocator);
        errdefer self.nextdirty.deinit();
        for (numComponents) |*c| try self.dirty.put(c, .{});

        var maxinputs: usize = 1;
        var maxoutputs: usize = 1;
        for (numComponents) |*c| {
            if (c.numInputs > maxinputs) maxinputs = c.numInputs;
            if (c.numOutputs > maxoutputs) maxoutputs = c.numOutputs;
        }

        self.inputs = try digisim.allocator.alloc(Signal, maxinputs);
        errdefer digisim.allocator.free(self.inputs);
        self.outputs = try digisim.allocator.alloc(Signal, maxoutputs);
        errdefer digisim.allocator.free(self.outputs);
        self.dirtynets = std.AutoHashMap(*Net, void).init(digisim.allocator);
        errdefer self.dirtynets.deinit();
        self.traceports = std.AutoHashMap(*Port, void).init(digisim.allocator);
        errdefer self.traceports.deinit();
        for (numComponents) |*c| {
            try self.dirty.put(c, .{});
        }
        self.pq = Pq.init(digisim.allocator, .{});
        errdefer self.pq.deinit();
        return self;
    }

    pub fn deinit(self: *@This()) void {
        self.pq.deinit();
        self.traceports.deinit();
        self.dirtynets.deinit();
        self.digisim.allocator.free(self.inputs);
        self.digisim.allocator.free(self.outputs);
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

    pub fn step(self: *@This()) !bool {
        var iter = self.dirty.keyIterator();
        while (iter.next()) |e| {
            const component = e.*;
            var idx: usize = 0;
            const inputs = self.inputs[0..component.numInputs];
            for (component.inports) |port| {
                for (port.pins) |*pin| {
                    inputs[idx] = Signal.collapse(pin.net.value);
                    idx += 1;
                }
            }

            const outputs = self.outputs[0..component.numOutputs];
            const nextSchedule = component.handler(self.timestamp, inputs, outputs, component.data);
            if (nextSchedule != 0) {
                try self.pq.add(.{ .timestamp = self.timestamp + nextSchedule, .component = component });
            }

            idx = 0;
            for (component.outports) |port| {
                for (port.pins) |*pin| {
                    const value = outputs[idx];
                    if (value != pin.value) {
                        pin.value = value;
                        try self.dirtynets.put(pin.net, .{});
                    }
                    idx += 1;
                }
            }
        }

        var i = self.dirtynets.keyIterator();
        while (i.next()) |e| {
            const net = e.*;
            var value = Signal.z;
            for (net.driverlist orelse unreachable) |d| {
                value = Signal.resolve(value, d.value);
            }
            if (Signal.tovcd(value) != Signal.tovcd(net.value)) {
                if (net.tracelist) |tracelist| {
                    for (tracelist) |t| {
                        try self.traceports.put(t, .{});
                    }
                }
            }
            if (value != net.value) {
                net.value = value;
                if (net.sensitivitylist) |sensitivitylist| {
                    for (sensitivitylist) |c| {
                        try self.nextdirty.put(c, .{});
                    }
                }
            }
        }

        if (self.traceports.count() > 0) {
            stdout.print("#{d}\n", .{self.timestamp}) catch ({});
            var j = self.traceports.keyIterator();
            while (j.next()) |p| {
                p.*.trace();
            }
        }

        const t = self.dirty;
        self.dirty = self.nextdirty;
        self.nextdirty = t;
        self.nextdirty.clearRetainingCapacity();
        self.dirtynets.clearRetainingCapacity();
        self.traceports.clearRetainingCapacity();
        self.timestamp += 1;
        return self.dirty.count() == 0;
    }
};
