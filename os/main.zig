const std = @import("std");
const Allocator = std.mem.Allocator;
var __heap: [32768 + 16384]u8 = undefined;

const Solver = struct {
    heap: *Allocator,
    nodes: [*]Node,
    gs: usize,
    gw: usize,
    s: usize,

    const Node = struct { top: *Node, up: *Node, down: *Node, left: *Node, right: *Node, data: union { n: usize, a: packed struct { cell: u16, value: u16 } } };

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
        root.data.n = 0;
        var constraints: []*Node = try heap.alloc(*Node, numconstraints);
        defer heap.free(constraints);
        var prev = root;
        for (constraints) |_, index| {
            const constraint = &ret.nodes[ptr];
            ptr += 1;
            constraints[index] = constraint;
            prev.right = constraint;
            constraint.left = prev;
            prev = constraint;
            constraint.top = constraint;
            constraint.up = constraint;
            constraint.down = constraint;
            constraint.data.n = 0;
        }
        prev.right = root;
        root.left = prev;
        prev = root;
        var index: usize = 0;
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

            action.data.a.cell = @intCast(u16, cell);
            action.data.a.value = @intCast(u16, value);

            const ac = [_]*Node{ constraints[cell], constraints[cell * 1 + row * gw + value], constraints[cell * 2 + col * gw + value], constraints[cell * 3 + sqr * gw + value] };
            var prevaction = action;
            for (ac) |top| {
                const an = &ret.nodes[ptr];
                ptr += 1;

                prevaction.right = an;
                an.left = prevaction;
                prevaction = an;

                an.top = top;
                top.data.n += 1;

                top.up.down = an;
                top.up = an;
                an.down = top;
                an.data.n = action.data.n;
            }
            action.left = prevaction;
            prevaction.right = action;
        }
        root.up = prev;
        prev.down = root;
        return ret;
    }

    pub fn solve(self: *Solver, puzzle: [*:0]u8) !bool {
        _ = self;
        _ = puzzle.len;
        for (puzzle) |char, index| {
            if (index >= self.gs)
                return error.PuzzleTooBig;

            var val: usize = 0;
            if (char >= '0' and char <= '9') {
                val = char - '0';
            } else if (char >= 'a' and char <= 'z') {
                val = char - 'a' + 10;
            } else if (char >= 'A' and char <= 'Z') {
                val = char - 'A' + 10;
            }
        }
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

    vol.* = Solver.new(allocator, 3) catch undefined;

    var puzzle = [_]u8{ 0, 1, 3, 5, 0, 0, 4, 2, 0, 0, 8, 7, 0, 0, 4, 0, 0, 0, 0, 0, 4, 0, 7, 9, 6, 0, 3, 0, 6, 2, 0, 4, 0, 5, 0, 8, 0, 0, 0, 0, 5, 0, 1, 0, 2, 0, 3, 8, 0, 9, 1, 0, 0, 0, 0, 0, 0, 9, 0, 0, 8, 0, 0, 7, 0, 0, 8, 1, 5, 0, 0, 9, 8, 9, 1, 0, 0, 7, 2, 5, 0 };
    if (solve(puzzle[0..])) {
        output(puzzle[0..]);
    }
}
