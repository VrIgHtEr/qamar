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
        var leaves = std.ArrayList(t.Id).init(self.allocator);
        defer leaves.deinit();
        var branches = std.ArrayList(t.Id).init(self.allocator);
        defer branches.deinit();
        var i = self.components.iterator();
        while (i.next()) |e| {
            if (e.value_ptr.isLeaf()) {
                try leaves.append(e.key_ptr.*);
            } else {
                try branches.append(e.key_ptr.*);
            }
        }

        for (leaves.items) |id| {
            try self.root.components.put(id, .{});
        }
        for (branches.items) |id| {
            var branch = self.components.getPtr(id) orelse unreachable;
            branch.components.clearAndFree();
            _ = self.root.components.swapRemove(id);
            branch.deinit();
        }
    }

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
            _ = self;
            _ = allocator;
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

    pub const Simulation = struct {
        allocator: Allocator,
        nets: []CompiledNet,
        components: []CompiledComponent,
        ports: []CompiledPort,
        dirty: std.AutoHashMap(*CompiledComponent, void),

        pub fn init(allocator: Allocator, numNets: usize, numComponents: usize, numPorts: usize) !@This() {
            var self: @This() = undefined;
            self.allocator = allocator;
            self.nets = try allocator.alloc(CompiledNet, numNets);
            errdefer allocator.free(self.nets);
            self.components = try allocator.alloc(CompiledComponent, numComponents);
            errdefer allocator.free(self.components);
            self.ports = try allocator.alloc(CompiledPort, numPorts);
            errdefer allocator.free(self.ports);
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

    pub fn compile(self: *@This()) !void {
        if (self.components.count() == 0) return Error.EmptySimulation;
        try self.checkLeafNodes();
        try self.checkUnconnectedInputs();

        try self.assignNames();
        try self.flatten();

        var netmap = std.AutoHashMap(t.Id, *CompiledNet).init(self.allocator);
        defer netmap.deinit();
        var sim = try Simulation.init(self.allocator, self.nets.count(), self.components.count(), self.ports.count());
        defer sim.deinit();
        _ = sim.step();
    }
};
