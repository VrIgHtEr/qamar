const IdGen = @import("idgen.zig").IdGen;
const Component = @import("tree/component.zig").Component;
const Port = @import("tree/port.zig").Port;
const Pin = @import("tree/pin.zig").Pin;
const Net = @import("tree/net.zig").Net;
const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const stringIntern = @import("stringIntern.zig");
const root_name: []const u8 = "__ROOT__";
const Signal = @import("signal.zig").Signal;
const stdout = std.io.getStdOut().writer();
const Lua = @import("lua.zig").Lua;
const stdlib = @cImport({
    @cInclude("stdlib.h");
});

const relpath = "../share/digisim";

fn HashMap(comptime T: type) type {
    return std.AutoArrayHashMap(usize, T);
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
    FaultedState,
    SimulationLocked,
    InvalidRootNode,
    InitializationFailed,
};

pub const Digisim = struct {
    allocator: Allocator,
    id: usize = 0,
    root: Component,
    strings: stringIntern.StringIntern,
    components: HashMap(Component),
    ports: HashMap(Port),
    nets: HashMap(Net),
    idgen: IdGen,
    faulted: bool,
    locked: bool,
    compiled: ?*Simulation,
    lua: Lua,

    pub fn init(allocator: Allocator) !*@This() {
        var self: *@This() = try allocator.create(@This());
        errdefer allocator.destroy(self);
        self.faulted = false;
        self.allocator = allocator;
        self.id = 0;
        self.locked = false;
        self.compiled = null;
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
        self.lua = try Lua.init(self);
        errdefer self.lua.deinit();
        const str = stdlib.realpath("/proc/self/exe", 0);
        if (str) |s| {
            defer stdlib.free(s);
            const dirname = std.fs.path.dirname(std.mem.span(s));
            if (dirname) |dname| {
                const luapath = try std.fs.path.joinZ(allocator, &[_][]const u8{ dname, "/", relpath });
                defer allocator.free(luapath);
                const finalLuaPath = stdlib.realpath(luapath, 0);
                if (finalLuaPath) |p| {
                    defer stdlib.free(p);
                    try self.lua.setupenv(std.mem.span(finalLuaPath));
                }
            }
        } else return Error.InitializationFailed;
        return self;
    }

    pub fn checkFaulted(self: *@This()) !void {
        if (self.locked and self.compiled == null) self.faulted = true;
        if (self.faulted) return Error.FaultedState;
    }

    pub fn runLuaSetup(self: *@This()) !void {
        errdefer self.faulted = true;
        try self.checkFaulted();
        try self.lua.execute("require 'init'");
    }

    fn deinitRoot(self: *@This()) void {
        self.root.deinit();
        self.nets.deinit();
        self.ports.deinit();
        self.components.deinit();
        self.idgen.deinit();
    }

    pub fn deinit(self: *@This()) void {
        if (self.compiled) |c| {
            c.deinit();
        } else {
            self.deinitRoot();
        }
        self.strings.deinit();
        self.lua.deinit();
        self.allocator.destroy(self);
    }

    pub fn nextId(self: *@This()) usize {
        const ret = self.id;
        self.id += 1;
        return ret;
    }

    pub fn step(self: *@This()) !bool {
        errdefer self.faulted = true;
        try self.checkFaulted();
        if (!self.locked) try self.compile();
        return (self.compiled orelse unreachable).step();
    }

    pub fn addComponent(self: *@This(), name: []const u8) !usize {
        try self.checkFaulted();
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

    pub fn traceAllPorts(self: *@This()) void {
        var ci = self.ports.iterator();
        while (ci.next()) |e| {
            e.value_ptr.trace = true;
        }
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
        stdout.print("$timescale 1ps $end\n", .{}) catch ({});
        try self.root.assignNames();
        stdout.print("$enddefinitions $end\n", .{}) catch ({});
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
        var nodes = std.ArrayList(usize).init(self.allocator);
        defer nodes.deinit();
        var ports = std.ArrayList(usize).init(self.allocator);
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
    const Simulation = @import("simulation.zig").Simulation;
    const NetMap = std.AutoHashMap(usize, *CompiledNet);
    const ComponentMap = std.AutoHashMap(usize, *CompiledComponent);
    const PortMap = std.AutoHashMap(usize, *CompiledPort);

    fn populateComponents(self: *@This(), components: []CompiledComponent, map: *ComponentMap) !void {
        var ret: usize = 0;
        errdefer while (ret > 0) {
            ret -= 1;
            components[ret].deinit(self.allocator);
        };

        var i = self.components.iterator();
        while (i.next()) |v| {
            if (v.value_ptr.isLeaf()) {
                std.debug.print("COMPILE COMP: {s}\n", .{v.value_ptr.name});
                var numinports: usize = 0;
                var numoutports: usize = 0;
                components[ret].numInputs = 0;
                components[ret].numOutputs = 0;
                {
                    var j = v.value_ptr.ports.iterator();
                    while (j.next()) |p| {
                        var port = self.ports.getPtr(p.key_ptr.*) orelse unreachable;
                        if (port.input) {
                            numinports += 1;
                            components[ret].numInputs += port.width();
                        } else {
                            numoutports += 1;
                            components[ret].numOutputs += port.width();
                        }
                    }
                }
                components[ret].handler = v.value_ptr.handler orelse unreachable;
                components[ret].inports = try self.allocator.alloc(*CompiledPort, numinports);
                errdefer self.allocator.free(components[ret].inports);
                components[ret].outports = try self.allocator.alloc(*CompiledPort, numoutports);
                errdefer self.allocator.free(components[ret].outports);
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
            ports[ret].deinit(self);
        };
        var i = self.components.iterator();
        while (i.next()) |v| {
            if (v.value_ptr.isLeaf()) {
                var j = v.value_ptr.ports.iterator();
                var inidx: usize = 0;
                var outidx: usize = 0;
                const ccomp = cmap.get(v.key_ptr.*) orelse unreachable;
                while (j.next()) |e| {
                    const port = self.ports.getPtr(e.key_ptr.*) orelse unreachable;
                    std.debug.print("COMPILE PORT {s}.{s}\n", .{ v.value_ptr.name, port.name });
                    ports[ret].pins = try self.allocator.alloc(CompiledPin, port.pins.len);
                    errdefer self.allocator.free(ports[ret].pins);
                    ports[ret].alias = port.alias;
                    port.alias = null;
                    errdefer ({
                        port.alias = ports[ret].alias;
                        ports[ret].alias = null;
                    });
                    try map.put(port.id, &ports[ret]);
                    if (port.input) {
                        ccomp.inports[inidx] = &ports[ret];
                        inidx += 1;
                    } else {
                        ccomp.outports[outidx] = &ports[ret];
                        outidx += 1;
                    }
                    ret += 1;
                }
            } else {
                var j = v.value_ptr.ports.iterator();
                while (j.next()) |je| {
                    const port = self.ports.getPtr(je.key_ptr.*) orelse unreachable;
                    if (port.trace) {
                        std.debug.print("COMPILE PORT {s}.{s}\n", .{ v.value_ptr.name, port.name });
                        ports[ret].pins = try self.allocator.alloc(CompiledPin, port.pins.len);
                        errdefer self.allocator.free(ports[ret].pins);
                        ports[ret].alias = port.alias;
                        port.alias = null;
                        errdefer ({
                            port.alias = ports[ret].alias;
                            ports[ret].alias = null;
                        });
                        try map.put(port.id, &ports[ret]);
                        ret += 1;
                    }
                }
            }
        }
    }

    fn countNetsToCompile(self: *@This()) !usize {
        var nets = std.AutoHashMap(usize, void).init(self.allocator);
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
        var nets = std.AutoHashMap(usize, void).init(self.allocator);
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
            cnets[ret].driverlist = null;
            cnets[ret].value = Signal.z;
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
                        cport.pins[idx].value = Signal.z;
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
                            cport.pins[idx].value = Signal.z;
                        }
                    }
                }
            }
        }
    }

    fn buildSensitivityLists(self: *@This(), cmap: *ComponentMap, nmap: *NetMap) !void {
        var sensitivityLists = std.AutoHashMap(usize, std.AutoHashMap(*CompiledComponent, void)).init(self.allocator);
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
                        if (port.input) {
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

    fn buildTraceLists(self: *@This(), pmap: *PortMap, nmap: *NetMap) !void {
        var traceLists = std.AutoHashMap(usize, std.AutoHashMap(*CompiledPort, void)).init(self.allocator);
        defer ({
            var i = traceLists.iterator();
            while (i.next()) |a| a.value_ptr.deinit();
            traceLists.deinit();
        });
        {
            var i = self.ports.iterator();
            while (i.next()) |e| {
                if (e.value_ptr.trace) {
                    const cport = pmap.get(e.key_ptr.*) orelse unreachable;
                    for (e.value_ptr.pins) |*pin| {
                        var map: *std.AutoHashMap(*CompiledPort, void) = undefined;
                        if (traceLists.getPtr(pin.net)) |p| {
                            map = p;
                        } else {
                            try traceLists.put(pin.net, std.AutoHashMap(*CompiledPort, void).init(self.allocator));
                            map = traceLists.getPtr(pin.net) orelse unreachable;
                        }
                        try map.put(cport, .{});
                    }
                }
            }
        }
        {
            var i = traceLists.iterator();
            while (i.next()) |e| {
                const cnet = nmap.get(e.key_ptr.*) orelse unreachable;
                const list = try self.allocator.alloc(*CompiledPort, e.value_ptr.count());
                errdefer self.allocator.free(list);
                var idx: usize = 0;
                var j = e.value_ptr.iterator();
                while (j.next()) |f| {
                    list[idx] = f.key_ptr.*;
                    idx += 1;
                }
                cnet.tracelist = list;
            }
        }
    }

    fn buildDriverLists(self: *@This(), pmap: *PortMap, nmap: *NetMap) !void {
        var driverLists = std.AutoHashMap(usize, std.ArrayList(*CompiledPin)).init(self.allocator);
        defer ({
            var i = driverLists.iterator();
            while (i.next()) |a| a.value_ptr.deinit();
            driverLists.deinit();
        });
        {
            var i = self.components.iterator();
            while (i.next()) |v| {
                if (v.value_ptr.isLeaf()) {
                    var j = v.value_ptr.ports.iterator();
                    while (j.next()) |e| {
                        const port = self.ports.getPtr(e.key_ptr.*) orelse unreachable;
                        if (!port.input) {
                            const cport = pmap.get(port.id) orelse unreachable;
                            for (port.pins) |*pin, idx| {
                                var map: *std.ArrayList(*CompiledPin) = undefined;
                                if (driverLists.getPtr(pin.net)) |p| {
                                    map = p;
                                } else {
                                    try driverLists.put(pin.net, std.ArrayList(*CompiledPin).init(self.allocator));
                                    map = driverLists.getPtr(pin.net) orelse unreachable;
                                }
                                try map.append(&cport.pins[idx]);
                            }
                        }
                    }
                }
            }
        }
        {
            var i = driverLists.iterator();
            while (i.next()) |e| {
                const cnet = nmap.get(e.key_ptr.*) orelse unreachable;
                try e.value_ptr.ensureTotalCapacityPrecise(e.value_ptr.items.len);
                cnet.driverlist = e.value_ptr.toOwnedSlice();
            }
        }
    }

    fn compile(self: *@This()) !void {
        try self.checkFaulted();
        if (self.locked) return;
        if (self.components.count() == 0) return Error.EmptySimulation;
        if (self.root.isLeaf()) return Error.InvalidRootNode;
        try self.checkLeafNodes();
        try self.checkUnconnectedInputs();
        self.locked = true;

        self.checkTraces();
        try self.assignNames();
        try self.flatten();
        try self.purgeBranches();

        var components = try self.allocator.alloc(CompiledComponent, self.countComponentsToCompile());
        std.debug.print("COUNT COMP {d}\n", .{components.len});
        errdefer self.allocator.free(components);
        var componentMap = ComponentMap.init(self.allocator);
        defer componentMap.deinit();
        try self.populateComponents(components, &componentMap);
        errdefer for (components) |*e| e.deinit(self.allocator);

        var ports = try self.allocator.alloc(CompiledPort, self.countPortsToCompile());
        std.debug.print("COUNT PORT {d}\n", .{ports.len});
        errdefer self.allocator.free(ports);
        var portMap = PortMap.init(self.allocator);
        defer portMap.deinit();
        try self.populatePorts(ports, &portMap, &componentMap);
        errdefer for (ports) |*e| e.deinit(self);

        var nets = try self.allocator.alloc(CompiledNet, try self.countNetsToCompile());
        std.debug.print("COUNT NET  {d}\n", .{nets.len});
        errdefer self.allocator.free(nets);
        var netMap = NetMap.init(self.allocator);
        defer netMap.deinit();
        try self.populateNets(nets, &netMap);
        errdefer for (nets) |*e| e.deinit(self.allocator);
        self.populatePins(&portMap, &netMap);
        try self.buildSensitivityLists(&componentMap, &netMap);
        try self.buildTraceLists(&portMap, &netMap);
        try self.buildDriverLists(&portMap, &netMap);

        self.compiled = try Simulation.init(self, nets, components, ports);
        self.deinitRoot();
    }
};
