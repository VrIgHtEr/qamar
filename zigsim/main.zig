const std = @import("std");
const Allocator = std.mem.Allocator;

const Id = usize;

const ArrayList = std.ArrayList;

const Net = struct { id: Id };
const NetHash = std.AutoArrayHashMap(Id, Net);

const Pin = struct { id: Id };
const PinHash = std.AutoArrayHashMap(Id, Pin);

const Port = struct {
    id: Id,
    pins: PinHash,
    pub fn init(allocator: Allocator, id: Id) @This() {
        var self: @This() = undefined;
        self.id = id;
        self.pins = PinHash.init(allocator);
    }
    pub fn deinit(self: *@This()) void {
        self.pins.deinit();
    }
};
const PortHash = std.AutoArrayHashMap(Id, Port);

const Component = struct {
    id: Id,
    ports: PortHash,
    pub fn init(allocator: Allocator, id: Id) @This() {
        var self: @This() = undefined;
        self.id = id;
        self.ports = PortHash.init(allocator);
        return self;
    }
    pub fn deinit(self: *@This()) void {
        var i = self.ports.iterator();
        while (i.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.ports.deinit();
    }
};
const ComponentHash = std.AutoArrayHashMap(Id, Component);

const Digisim = struct {
    id: Id = 0,
    components: ComponentHash,
    pub fn init(allocator: Allocator) @This() {
        var self: @This() = undefined;
        self.id = 0;
        self.components = ComponentHash.init(allocator);
        return self;
    }

    pub fn deinit(self: *@This()) void {
        var i = self.components.iterator();
        while (i.next()) |component| {
            component.value_ptr.deinit();
        }
        self.components.deinit();
    }
};

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var sim: Digisim = Digisim.init(allocator);
    defer sim.deinit();
    return 0;
}
