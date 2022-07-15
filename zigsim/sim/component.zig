const std = @import("std");
const t = @import("../types.zig");
const Port = @import("port.zig").Port;
const Net = @import("net.zig").Net;
const digi = @import("../digisim.zig");
const HashMap = std.AutoArrayHashMap(t.Id, void);
const Digisim = digi.Digisim;
const Err = digi.Error;
const Signal = t.Signal;

pub const components = struct {
    pub fn nand_h(input: []Signal, output: []Signal) anyerror!void {
        for (input) |x| {
            if (x != Signal.high) {
                output[0] = Signal.high;
                return;
            }
        }
        output[0] = Signal.low;
    }
    pub fn and_h(input: []Signal, output: []Signal) anyerror!void {
        for (input) |x| {
            if (x != Signal.high) {
                output[0] = Signal.low;
                return;
            }
        }
        output[0] = Signal.high;
    }
    pub fn nor_h(input: []Signal, output: []Signal) anyerror!void {
        for (input) |x| {
            if (x == Signal.high) {
                output[0] = Signal.high;
                return;
            }
        }
        output[0] = Signal.low;
    }
    pub fn or_h(input: []Signal, output: []Signal) anyerror!void {
        for (input) |x| {
            if (x == Signal.high) {
                output[0] = Signal.low;
                return;
            }
        }
        output[0] = Signal.high;
    }
};

pub const Component = struct {
    id: t.Id,
    ports: HashMap,
    components: HashMap,
    name: []const u8,
    handler: ?fn ([]Signal, []Signal) anyerror!void,

    pub fn init(digisim: *Digisim, name: []const u8) !@This() {
        var self: @This() = undefined;
        self.id = digisim.nextId();
        self.ports = HashMap.init(digisim.allocator);
        self.components = HashMap.init(digisim.allocator);
        self.name = name;
        self.handler = null;
        return self;
    }

    pub fn setHandler(self: *@This(), handler: fn ([]Signal, []Signal) anyerror!void) Err!void {
        if (self.handler != null) return Err.HandlerAlreadySet;
        self.handler = handler;
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

    fn charToDigit(c: u8) u8 {
        return switch (c) {
            '0'...'9' => c - '0',
            'A'...'Z' => c - 'A' + 10,
            'a'...'z' => c - 'a' + 10,
            else => std.math.maxInt(u8),
        };
    }

    fn parseUsize(buf: []const u8, radix: u8) !usize {
        var x: u64 = 0;

        for (buf) |c| {
            const digit = charToDigit(c);

            if (digit >= radix) {
                return error.InvalidChar;
            }

            // x *= radix
            if (@mulWithOverflow(u64, x, radix, &x)) {
                return error.Overflow;
            }

            // x += digit
            if (@addWithOverflow(u64, x, digit, &x)) {
                return error.Overflow;
            }
        }

        return x;
    }

    fn parsePortRange(self: *@This(), digisim: *Digisim, p: []const u8) !struct {
        port: *Port,
        start: usize,
        end: usize,
        pub fn width(s: *const @This()) usize {
            return s.end - s.start + 1;
        }
    } {
        var port_name: []const u8 = undefined;
        var range: []const u8 = undefined;
        if (std.mem.lastIndexOf(u8, p, "[")) |index| {
            port_name = p[0..index];
            range = p[index..];
        } else {
            port_name = p;
            range = p[0..0];
        }
        var comp = self;
        while (std.mem.indexOf(u8, port_name, ".")) |i| {
            const compName = port_name[0..i];
            port_name = port_name[i + 1 ..];
            if (digisim.strings.get(compName)) |icompName| {
                if (comp.findComponentByName(digisim, icompName)) |foundComponent| {
                    comp = foundComponent;
                } else return Err.ComponentNotFound;
            } else return Err.ComponentNotFound;
        }
        const port = (try comp.getPort(digisim, port_name)) orelse return Err.PortNotFound;
        var start: usize = undefined;
        var end: usize = undefined;
        if (range.len == 0) {
            start = port.start;
            end = port.end;
        } else {
            if (range[0] != '[' or range[range.len - 1] != ']') return Err.InvalidPortReference;
            range = range[1 .. range.len - 1];
            if (range.len == 0) return Err.InvalidPortReference;
            if (std.mem.indexOf(u8, range, "-")) |dashindex| {
                if (dashindex == 0) {
                    if (range.len == 1) return Err.InvalidPortReference;
                    start = port.start;
                } else {
                    start = parseUsize(range[0..dashindex], 10) catch return Err.InvalidPortReference;
                }
                if (dashindex == range.len - 1) {
                    end = port.end;
                } else {
                    end = parseUsize(range[dashindex + 1 ..], 10) catch return Err.InvalidPortReference;
                }
            } else {
                start = parseUsize(range, 10) catch return Err.InvalidPortReference;
                end = start;
            }
        }
        if (end < start) return Err.InvalidPortReference;
        if (start < port.start) return Err.PortReferenceOutOfRange;
        if (end > port.end) return Err.PortReferenceOutOfRange;
        const ret = .{ .port = port, .start = start, .end = end };
        return ret;
    }

    pub fn connect(self: *@This(), digisim: *Digisim, a: []const u8, b: []const u8) !void {
        const pa = try self.parsePortRange(digisim, a);
        const pb = try self.parsePortRange(digisim, b);

        const w = pa.width();
        if (w != pb.width()) return Err.MismatchingPortWidths;
        var i: usize = 0;
        while (i < w) : (i += 1) {
            const p1 = &pa.port.pins[pa.start + i];
            const p2 = &pb.port.pins[pb.start + i];
            if (p1.net != p2.net) {
                const net1 = digisim.nets.getPtr(p1.net) orelse unreachable;
                const net2 = digisim.nets.getPtr(p2.net) orelse unreachable;
                try net1.merge(digisim, net2);
            }
        }
    }

    pub fn addPort(self: *@This(), digisim: *Digisim, name: []const u8, input: bool, start: usize, end: usize, trace: bool) !t.Id {
        if (name.len == 0) return Err.InvalidPortName;
        if (std.mem.indexOf(u8, name, ".")) |_| return Err.InvalidPortName;
        const interned_name = try digisim.strings.ref(name);
        errdefer digisim.strings.unref(interned_name);
        var i = self.ports.iterator();
        while (i.next()) |e| {
            const entry = digisim.ports.getPtr(e.key_ptr.*) orelse unreachable;
            if (entry.name.ptr == interned_name.ptr) return Err.DuplicatePortName;
        }
        var p = try Port.init(digisim, interned_name, input, start, end, trace);
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

    pub fn isLeaf(self: *const @This()) bool {
        if (self.handler) |_| return true;
        return false;
    }

    pub fn assignNames(self: *@This(), digisim: *Digisim) Err!void {
        if (self.isLeaf()) {
            var i = self.ports.iterator();
            while (i.next()) |p| {
                const port = digisim.ports.getPtr(p.key_ptr.*) orelse unreachable;
                if (port.trace) {
                    port.alias = try digisim.idgen.refNewId(digisim);
                    std.debug.print("$var wire {d} {s} {s} $end\n", .{ port.width(), port.alias orelse unreachable, port.name });
                }
            }
        } else {
            var i = self.components.iterator();
            while (i.next()) |c| {
                const comp = digisim.components.getPtr(c.key_ptr.*) orelse unreachable;
                std.debug.print("$scope module {s} $end\n", .{comp.name});
                try comp.assignNames(digisim);
                std.debug.print("$upscope $end\n", .{});
            }
        }
    }
};
