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

    pub fn checkTraces(self: *@This()) void {
        _ = self.root.checkTraces();
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
            if (!e.value_ptr.isLeaf())
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
                try self.root.ports.put(portid, .{});
                _ = branch.ports.swapRemove(portid);
            }
            ports.clearRetainingCapacity();
            branch.deinit();
        }
    }

    fn countComponentsToCompile(self: *@This()) usize {
        var ret: usize = 0;
        var i = self.components.iterator();
        while (i.next()) |v| {
            if (v.value_ptr.isLeaf())
                ret += 1;
        }
        return ret;
    }

    const CompiledComponent = @import("comp/component.zig").Component;
    const CompiledPort = @import("comp/port.zig").Port;
    const CompiledPin = @import("comp/pin.zig").Pin;
    const CompiledNet = @import("comp/net.zig").Net;
    const Simulation = @import("comp/simulation.zig").Simulation;
    const NetMap = std.AutoHashMap(t.Id, *CompiledNet);
    const ComponentMap = std.AutoHashMap(t.Id, *CompiledComponent);
    const PortMap = std.AutoHashMap(t.Id, *CompiledPort);

    fn populateComponents(self: *@This(), components: []CompiledComponent, map: *ComponentMap) !void {
        var ret: usize = 0;
        errdefer while (ret > 0) {
            ret -= 1;
            components[ret].deinit(self.allocator);
        };

        var i = self.components.iterator();
        while (i.next()) |v| {
            if (v.value_ptr.isLeaf()) {
                components[ret].ports = try self.allocator.alloc(*CompiledPort, v.value_ptr.ports.count());
                errdefer components[ret].deinit(self.allocator);
                try map.put(v.value_ptr.id, &components[ret]);
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

    fn populatePorts(self: *@This(), ports: []CompiledPort, map: *PortMap, cmap: *ComponentMap) !void {
        var ret: usize = 0;
        errdefer while (ret > 0) {
            ret -= 1;
            ports[ret].deinit(self.allocator);
        };
        var i = self.components.iterator();
        while (i.next()) |v| {
            if (v.value_ptr.isLeaf()) {
                var j = v.value_ptr.ports.iterator();
                var idx: usize = 0;
                const cports = (cmap.get(v.key_ptr.*) orelse unreachable).ports;
                while (j.next()) |e| {
                    const port = self.ports.getPtr(e.key_ptr.*) orelse unreachable;
                    ports[ret].pins = try self.allocator.alloc(CompiledPin, port.pins.len);
                    errdefer self.allocator.free(ports[ret].pins);
                    try map.put(port.id, &ports[ret]);
                    cports[idx] = &ports[ret];
                    idx += 1;
                    ret += 1;
                }
            } else {
                var j = v.value_ptr.ports.iterator();
                while (j.next()) |je| {
                    const port = self.ports.getPtr(je.key_ptr.*) orelse unreachable;
                    if (port.trace) {
                        ports[ret].pins = try self.allocator.alloc(CompiledPin, port.pins.len);
                        errdefer self.allocator.free(ports[ret].pins);
                        try map.put(port.id, &ports[ret]);
                        ret += 1;
                    }
                }
            }
        }
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
                    if (port.trace) {
                        for (port.pins) |*pin| {
                            try nets.put(pin.net, .{});
                        }
                    }
                }
            }
        }
        return nets.count();
    }

    fn populateNets(self: *@This(), cnets: []CompiledNet, map: *NetMap) !void {
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
                    if (port.trace) {
                        for (port.pins) |*pin| {
                            try nets.put(pin.net, .{});
                        }
                    }
                }
            }
        }
        var ret: usize = 0;
        errdefer while (ret > 0) {
            ret -= 1;
            cnets[ret].deinit(self.allocator);
        };
        var j = nets.iterator();
        while (j.next()) |e| {
            try map.put(e.key_ptr.*, &cnets[ret]);
            cnets[ret].tracelist = null;
            cnets[ret].sensitivitylist = null;
            ret += 1;
        }
    }

    fn populatePins(self: *@This(), pmap: *PortMap, nmap: *NetMap) void {
        var i = self.components.iterator();
        while (i.next()) |v| {
            if (v.value_ptr.isLeaf()) {
                var j = v.value_ptr.ports.iterator();
                while (j.next()) |e| {
                    const port = self.ports.getPtr(e.key_ptr.*) orelse unreachable;
                    const cport = pmap.get(port.id) orelse unreachable;
                    for (port.pins) |*pin, idx| {
                        cport.pins[idx].net = nmap.get(pin.net) orelse unreachable;
                    }
                }
            } else {
                var j = v.value_ptr.ports.iterator();
                while (j.next()) |je| {
                    const port = self.ports.getPtr(je.key_ptr.*) orelse unreachable;
                    if (port.trace) {
                        const cport = pmap.get(port.id) orelse unreachable;
                        for (port.pins) |*pin, idx| {
                            cport.pins[idx].net = nmap.get(pin.net) orelse unreachable;
                        }
                    }
                }
            }
        }
    }

    const SensitivityListCollection = std.AutoHashMap(t.Id, std.AutoHashMap(*CompiledComponent, void));

    fn buildSensitivityLists(self: *@This(), cmap: *ComponentMap, nmap: *NetMap) !void {
        var sensitivityLists = SensitivityListCollection.init(self.allocator);
        defer ({
            var i = sensitivityLists.iterator();
            while (i.next()) |a| a.value_ptr.deinit();
            sensitivityLists.deinit();
        });
        {
            var i = self.components.iterator();
            while (i.next()) |v| {
                if (v.value_ptr.isLeaf()) {
                    var j = v.value_ptr.ports.iterator();
                    while (j.next()) |e| {
                        const port = self.ports.getPtr(e.key_ptr.*) orelse unreachable;
                        for (port.pins) |*pin| {
                            var map: *std.AutoHashMap(*CompiledComponent, void) = undefined;
                            if (sensitivityLists.getPtr(pin.net)) |p| {
                                map = p;
                            } else {
                                try sensitivityLists.put(pin.net, std.AutoHashMap(*CompiledComponent, void).init(self.allocator));
                                map = sensitivityLists.getPtr(pin.net) orelse unreachable;
                            }
                            try map.put(cmap.get(v.value_ptr.id) orelse unreachable, .{});
                        }
                    }
                }
            }
        }
        {
            var i = sensitivityLists.iterator();
            while (i.next()) |e| {
                const cnet = nmap.get(e.key_ptr.*) orelse unreachable;
                const list = try self.allocator.alloc(*CompiledComponent, e.value_ptr.count());
                errdefer self.allocator.free(list);
                var idx: usize = 0;
                var j = e.value_ptr.iterator();
                while (j.next()) |f| {
                    list[idx] = f.key_ptr.*;
                    idx += 1;
                }
                cnet.sensitivitylist = list;
            }
        }
    }

    pub fn compile(self: *@This()) !*Simulation {
        if (self.components.count() == 0) return Error.EmptySimulation;
        try self.checkLeafNodes();
        try self.checkUnconnectedInputs();

        self.checkTraces();
        try self.assignNames();
        try self.flatten();
        try self.purgeBranches();

        var components = try self.allocator.alloc(CompiledComponent, self.countComponentsToCompile());
        errdefer self.allocator.free(components);
        var componentMap = ComponentMap.init(self.allocator);
        defer componentMap.deinit();
        try self.populateComponents(components, &componentMap);
        errdefer for (components) |*e| e.deinit(self.allocator);

        var ports = try self.allocator.alloc(CompiledPort, self.countPortsToCompile());
        errdefer self.allocator.free(ports);
        var portMap = PortMap.init(self.allocator);
        defer portMap.deinit();
        try self.populatePorts(ports, &portMap, &componentMap);
        errdefer for (ports) |*e| e.deinit(self.allocator);

        var nets = try self.allocator.alloc(CompiledNet, try self.countNetsToCompile());
        errdefer self.allocator.free(nets);
        var netMap = NetMap.init(self.allocator);
        defer netMap.deinit();
        try self.populateNets(nets, &netMap);
        errdefer for (nets) |*e| e.deinit(self.allocator);

        self.populatePins(&portMap, &netMap);

        try self.buildSensitivityLists(&componentMap, &netMap);

        var sim = try Simulation.init(self.allocator, nets, components, ports);
        _ = sim.step();
        return sim;
    }
};
