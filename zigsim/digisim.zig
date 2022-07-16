const t = @import("types.zig");
const IdGen = @import("idgen.zig").IdGen;
const Component = @import("sim/component.zig").Component;
const Port = @import("sim/port.zig").Port;
const Pin = @import("sim/pin.zig").Pin;
const Net = @import("sim/net.zig").Net;
const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const stringIntern = @import("stringIntern.zig");
const root_name: []const u8 = "__ROOT__";

fn HashMap(comptime T: type) type {
    return std.AutoArrayHashMap(t.Id, T);
}

pub const Error = error{
    DuplicateComponentName,
    InvalidComponentName,
    DuplicatePortName,
    InvalidPortName,
    InvalidPortSize,
    MismatchingPortWidths,
    PortNotFound,
    InvalidPortReference,
    HandlerAlreadySet,
    PortReferenceOutOfRange,
    UnconnectedInput,
    MalformedLeafNode,
    EmptySimulation,
    ComponentNotFound,
    OutOfMemory,
};

pub const Digisim = struct {
    allocator: Allocator,
    id: t.Id = 0,
    root: Component,
    strings: stringIntern.StringIntern,
    components: HashMap(Component),
    ports: HashMap(Port),
    nets: HashMap(Net),
    idgen: IdGen,
    pub fn init(allocator: Allocator) !*@This() {
        var self: *@This() = try allocator.create(@This());
        errdefer allocator.destroy(self);
        self.allocator = allocator;
        self.id = 0;
        self.strings = stringIntern.StringIntern.init(allocator);
        errdefer self.strings.deinit();
        self.components = HashMap(Component).init(allocator);
        errdefer self.components.deinit();
        self.ports = HashMap(Port).init(allocator);
        errdefer self.ports.deinit();
        self.nets = HashMap(Net).init(allocator);
        errdefer self.nets.deinit();
        self.root = try Component.init(self, try self.strings.ref(root_name));
        errdefer self.root.deinit();
        self.idgen = try IdGen.init(allocator);
        errdefer self.idgen.deinit();
        return self;
    }

    pub fn deinit(self: *@This()) void {
        self.root.deinit();
        self.nets.deinit();
        self.ports.deinit();
        self.components.deinit();
        self.strings.deinit();
        self.idgen.deinit();
        self.allocator.destroy(self);
    }

    pub fn nextId(self: *@This()) t.Id {
        const ret = self.id;
        self.id += 1;
        return ret;
    }

    pub fn addComponent(self: *@This(), name: []const u8) !t.Id {
        return self.root.addComponent(name);
    }

    pub fn getComponent(self: *@This(), name: []const u8) !?*Component {
        return self.root.getComponent(name);
    }

    pub fn getPort(self: *@This(), name: []const u8) !?*Port {
        return self.root.getPort(self, name);
    }

    fn countPins(self: *@This()) usize {
        var i = self.ports.iterator();
        var ret: usize = 0;
        while (i.next()) |e| {
            ret += e.value_ptr.pins.len;
        }
        return ret;
    }

    pub fn checkLeafNodes(self: *@This()) !void {
        var i = self.components.iterator();
        while (i.next()) |e| {
            if (e.value_ptr.isLeaf()) {
                if (e.value_ptr.components.count() != 0) return Error.MalformedLeafNode;
            } else {
                if (e.value_ptr.components.count() == 0) return Error.MalformedLeafNode;
            }
        }
    }

    pub fn checkUnconnectedInputs(self: *@This()) !void {
        var i = self.components.iterator();
        while (i.next()) |e| {
            var j = e.value_ptr.ports.iterator();
            while (j.next()) |p| {
                var port = self.ports.getPtr(p.key_ptr.*) orelse unreachable;
                if (port.input) {
                    for (port.pins) |*pin| {
                        const net = self.nets.getPtr(pin.net) orelse unreachable;
                        if (!net.isDriven()) {
                            return Error.UnconnectedInput;
                        }
                    }
                }
            }
        }
    }

    pub fn assignNames(self: *@This()) !void {
        std.debug.print("$timescale 1ps $end\n", .{});
        try self.root.assignNames();
        std.debug.print("$enddefinitions $end\n", .{});
    }

    pub fn flatten(self: *@This()) !void {
        var i = self.components.iterator();
        while (i.next()) |e| {
            if (e.value_ptr.isLeaf()) {
                try self.root.components.put(e.key_ptr.*, .{});
            } else {
                e.value_ptr.components.clearAndFree();
            }
        }
    }

    pub fn purgeBranches(self: *@This()) !void {
        var nodes = std.ArrayList(t.Id).init(self.allocator);
        defer nodes.deinit();
        var ports = std.ArrayList(t.Id).init(self.allocator);
        defer ports.deinit();
        var i = self.components.iterator();
        while (i.next()) |e| {
            try nodes.append(e.key_ptr.*);
        }
        for (nodes.items) |id| {
            _ = self.root.components.swapRemove(id);
            const branch = self.components.getPtr(id) orelse unreachable;
            var j = branch.ports.iterator();
            while (j.next()) |portid| {
                const port = self.ports.getPtr(portid.key_ptr.*) orelse unreachable;
                if (port.trace) try ports.append(port.id);
            }
            for (ports.items) |portid| {
                (self.ports.getPtr(portid) orelse unreachable).phantom = true;
                try self.root.ports.put(portid, .{});
                _ = branch.ports.swapRemove(portid);
            }
            ports.clearRetainingCapacity();
            branch.deinit();
        }
    }

    pub const Simulation = struct {
        allocator: Allocator,
        nets: []CompiledNet,
        components: []CompiledComponent,
        ports: []CompiledPort,
        dirty: std.AutoHashMap(*CompiledComponent, void),

        pub fn init(allocator: Allocator, numNets: []CompiledNet, numComponents: []CompiledComponent, numPorts: []CompiledPort) !*@This() {
            const self = try allocator.create(@This());
            errdefer allocator.destroy(self);
            self.allocator = allocator;
            self.nets = numNets;
            self.components = numComponents;
            self.ports = numPorts;
            self.dirty = @TypeOf(self.dirty).init(allocator);
            return self;
        }

        pub fn deinit(self: *@This()) void {
            self.dirty.deinit();
            for (self.components) |*p| p.deinit(self.allocator);
            self.allocator.free(self.components);
            for (self.nets) |*p| p.deinit(self.allocator);
            self.allocator.free(self.nets);
            for (self.ports) |*p| p.deinit(self.allocator);
            self.allocator.free(self.ports);
            self.allocator.destroy(self);
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

    const CompiledPin = struct { net: *CompiledNet };

    const CompiledPort = struct {
        pins: []CompiledPin,

        fn deinit(self: *@This(), allocator: Allocator) void {
            _ = self;
            _ = allocator;
        }
    };

    const CompiledComponent = struct {
        ports: []*CompiledPort,

        fn deinit(self: *@This(), allocator: Allocator) void {
            allocator.free(self.ports);
        }
    };

    const CompiledNet = struct {
        sensitivitylist: []*CompiledComponent,
        tracelist: []*CompiledPort,

        fn deinit(self: *@This(), allocator: Allocator) void {
            _ = self;
            _ = allocator;
        }
    };

    fn countComponentsToCompile(self: *@This()) usize {
        var ret: usize = 0;
        var i = self.components.iterator();
        while (i.next()) |v| {
            if (v.value_ptr.isLeaf())
                ret += 1;
        }
        return ret;
    }

    fn populateComponents(self: *@This(), components: []CompiledComponent) !void {
        var ret: usize = 0;
        errdefer ({
            while (ret > 0) {
                ret -= 1;
                components[ret].deinit(self.allocator);
            }
        });
        var i = self.components.iterator();
        while (i.next()) |v| {
            if (v.value_ptr.isLeaf()) {
                components[ret].ports = try self.allocator.alloc(*CompiledPort, v.value_ptr.ports.count());
                ret += 1;
            }
        }
    }

    fn countPortsToCompile(self: *@This()) usize {
        var ret: usize = 0;
        var i = self.components.iterator();
        while (i.next()) |v| {
            if (v.value_ptr.isLeaf()) {
                ret += v.value_ptr.ports.count();
            } else {
                var j = v.value_ptr.ports.iterator();
                while (j.next()) |je| {
                    const port = self.ports.getPtr(je.key_ptr.*) orelse unreachable;
                    if (port.trace) ret += 1;
                }
            }
        }
        return ret;
    }

    fn countNetsToCompile(self: *@This()) !usize {
        var nets = std.AutoHashMap(t.Id, void).init(self.allocator);
        defer nets.deinit();
        var i = self.components.iterator();
        while (i.next()) |v| {
            if (v.value_ptr.isLeaf()) {
                var j = v.value_ptr.ports.iterator();
                while (j.next()) |je| {
                    const port = self.ports.getPtr(je.key_ptr.*) orelse unreachable;
                    for (port.pins) |*pin| {
                        try nets.put(pin.net, .{});
                    }
                }
            } else {
                var j = v.value_ptr.ports.iterator();
                while (j.next()) |je| {
                    const port = self.ports.getPtr(je.key_ptr.*) orelse unreachable;
                    for (port.pins) |*pin| {
                        try nets.put(pin.net, .{});
                    }
                }
            }
        }
        return nets.count();
    }

    pub fn compile(self: *@This()) !*Simulation {
        if (self.components.count() == 0) return Error.EmptySimulation;
        try self.checkLeafNodes();
        try self.checkUnconnectedInputs();

        try self.assignNames();
        try self.flatten();

        var components = try self.allocator.alloc(CompiledComponent, self.countComponentsToCompile());
        errdefer self.allocator.free(components);
        try self.populateComponents(components);

        errdefer ({
            for (components) |*e| e.deinit(self.allocator);
        });
        var ports = try self.allocator.alloc(CompiledPort, self.countPortsToCompile());
        errdefer self.allocator.free(ports);

        var nets = try self.allocator.alloc(CompiledNet, try self.countNetsToCompile());
        errdefer self.allocator.free(nets);

        try self.purgeBranches();
        var sim = try Simulation.init(self.allocator, nets, components, ports);
        _ = sim.step();
        return sim;
    }
};
