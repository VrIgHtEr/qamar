const std = @import("std");
const builtin = @import("builtin");
const prt = builtin.os.tag != std.Target.Os.Tag.freestanding;
const Allocator = std.mem.Allocator;
var __heap: [1048576]u8 = undefined;

fn print(comptime fmt: []const u8, args: anytype) void {
    if (prt) std.debug.print(fmt, args);
}

const Solver = struct {
    heap: *Allocator,
    nodes: [*]Node,
    gs: usize,
    gw: usize,
    s: usize,

    const Node = struct { top: *Node, up: *Node, down: *Node, left: *Node, right: *Node, data: packed struct { cell: u16, value: u16 } };

    pub fn new(heap: *Allocator, square: usize) !Solver {
        const gw = square * square;
        const gs = gw * gw;
        const numconstraints = gs * 4;
        const numactions = gw * gs;
        const numnodes = numactions + numactions * 4 + numconstraints + 1;
        const alloc = try heap.alloc(Node, numnodes);
        var ret: Solver = undefined;
        ret.heap = heap;
        ret.nodes = alloc.ptr;
        ret.gs = gs;
        ret.gw = gw;
        ret.s = square;
        var ptr: usize = 0;
        var root = &ret.nodes[ptr];
        ptr += 1;
        root.top = root;
        root.left = root;
        root.right = root;
        root.down = root;
        root.up = root;
        root.data.cell = 0;
        root.data.value = 0;
        var prev = root;
        var index: usize = 0;
        while (index < numconstraints) : (index += 1) {
            const constraint = &ret.nodes[ptr];
            ptr += 1;
            prev.right = constraint;
            constraint.left = prev;
            prev = constraint;
            constraint.top = constraint;
            constraint.up = constraint;
            constraint.down = constraint;
            constraint.data.cell = 0;
            constraint.data.value = 0;
        }
        prev.right = root;
        root.left = prev;
        prev = root;
        index = 0;
        while (index < numactions) : (index += 1) {
            const action = &ret.nodes[ptr];
            ptr += 1;
            prev.down = action;
            action.up = prev;
            prev = action;
            action.top = root;

            const value = index / gs;
            const cell = index % gs;
            const row = cell / gw;
            const col = cell % gw;
            const strip = col % square;
            const plank = row % square;
            const sqr = plank * square + strip;

            action.data.cell = @truncate(u16, cell);
            action.data.value = @truncate(u16, value);

            const ac = [_]*Node{ &ret.nodes[cell + 1], &ret.nodes[cell * 1 + row * gw + value + 1], &ret.nodes[cell * 2 + col * gw + value + 1], &ret.nodes[cell * 3 + sqr * gw + value + 1] };
            var prevaction = action;
            for (ac) |top| {
                const an = &ret.nodes[ptr];
                ptr += 1;

                prevaction.right = an;
                an.left = prevaction;
                prevaction = an;

                an.top = top;
                top.data.value += 1;

                top.up.down = an;
                top.up = an;
                an.down = top;
                an.data = action.data;
            }
            action.left = prevaction;
            prevaction.right = action;
        }
        root.up = prev;
        prev.down = root;
        return ret;
    }

    pub fn solve(self: *const Solver, puzzle: [*]u8) !bool {
        _ = self;
        _ = self.gs;

        var index: usize = 0;
        while (index < self.gs) : (index += 1) {
            const char = puzzle[index];
            var val: usize = 0;
            if (char >= '0' and char <= '9') {
                val = char - '0';
            } else if (char >= 'a' and char <= 'z') {
                val = char - 'a' + 10;
            } else if (char >= 'A' and char <= 'Z') {
                val = char - 'A' + 10;
            }
        }
        return false;
    }
};

const swidth: u8 = 3;
const bwidth: u8 = swidth * swidth;
const bsize: u8 = bwidth * bwidth;

var out: u8 = undefined;
var h_out: *volatile u8 = &out;

pub fn output(grid: []u8) void {
    for (grid) |item| {
        h_out.* = item;
    }
}

pub fn solve(grid: []u8) bool {
    var g: [bsize]u8 = undefined;
    @memcpy(&g, grid.ptr, bsize);

    var subcell: u8 = bsize;
    var submark: [bwidth + 1]u8 = undefined;
    var mark: [bwidth + 1]u8 = undefined;
    mark[0] = 0;
    @memset(mark[1..], 1, bwidth);

    while (true) {
        var subs: u8 = 0;
        var row: u8 = 0;
        var cell: u8 = 0;
        var rl: u8 = 0;

        while (row < bwidth) : ({
            row += 1;
            rl += bwidth;
        }) {
            var col: u8 = 0;
            while (col < bwidth) : ({
                col += 1;
                cell += 1;
            }) {
                if (g[cell] == 0) {
                    @memset(&mark, 1, bwidth + 1);
                    mark[0] = 0;
                    var r: u8 = rl;
                    var c: u8 = col;
                    var s: u8 = ((swidth * bwidth) * (row / swidth)) + (swidth * (col / swidth));

                    var x: u8 = 0;
                    while (x < swidth) : ({
                        x += 1;
                        s += bwidth - swidth;
                    }) {
                        var y: u8 = 0;
                        while (y < swidth) : ({
                            y += 1;
                            r += 1;
                            c += bwidth;
                            s += 1;
                        }) {
                            mark[g[r]] = 0;
                            mark[g[c]] = 0;
                            mark[g[s]] = 0;
                        }
                    }

                    var val: u8 = undefined;
                    var count: u8 = 0;
                    for (mark[1..]) |item, index| {
                        if (item != 0) {
                            val = @intCast(u8, index + 1);
                            count += 1;
                        }
                    }
                    if (count == 0) {
                        return false;
                    } else if (count == 1) {
                        g[cell] = val;
                        subs += 1;
                    } else {
                        subcell = cell;
                        @memcpy(&submark, &mark, bwidth + 1);
                    }
                }
            }
        }
        if (subs == 0 or subcell >= bsize)
            break;
    }
    if (subcell < bsize) {
        for (submark[1..]) |item, index| {
            if (item != 0) {
                g[subcell] = @intCast(u8, index + 1);
                if (solve(g[0..])) {
                    subcell = bsize;
                    break;
                }
            }
        }
    }
    if (subcell >= bsize) {
        @memcpy(grid.ptr, g[0..], bsize);
        return true;
    }
    return false;
}

var vol: *volatile Solver = undefined;

pub export fn main() void {
    var fba = std.heap.FixedBufferAllocator.init(__heap[0..]);
    var allocator = &fba.allocator();
    vol = allocator.create(Solver) catch undefined;
    const sqsize = 3;
    const gwidth = sqsize * sqsize;
    const gsize = gwidth * gwidth;
    vol.* = Solver.new(allocator, sqsize) catch undefined;
    var pzl: [gsize]u8 = undefined;
    @memcpy(&pzl, "013500420087004000004079603062040508000050102038091000000900800700815009891007250", gsize);
    var slv = @ptrCast(*Solver, vol);
    _ = slv.solve(&pzl) catch undefined;

    var puzzle = [_]u8{ 0, 1, 3, 5, 0, 0, 4, 2, 0, 0, 8, 7, 0, 0, 4, 0, 0, 0, 0, 0, 4, 0, 7, 9, 6, 0, 3, 0, 6, 2, 0, 4, 0, 5, 0, 8, 0, 0, 0, 0, 5, 0, 1, 0, 2, 0, 3, 8, 0, 9, 1, 0, 0, 0, 0, 0, 0, 9, 0, 0, 8, 0, 0, 7, 0, 0, 8, 1, 5, 0, 0, 9, 8, 9, 1, 0, 0, 7, 2, 5, 0 };
    if (solve(puzzle[0..])) {
        output(puzzle[0..]);
    }
}
