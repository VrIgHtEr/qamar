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
    stack: [*]*Node,
    pq: [*]*Node,
    pqsize: usize,
    stackptr: usize,
    gs: usize,
    gw: usize,
    s: usize,

    const ConstraintType = enum(u2) {
        row,
        col,
        square,
    };

    const Node = struct {
        top: *Node,
        up: *Node,
        down: *Node,
        left: *Node,
        right: *Node,
        pqindex: usize,
        data: packed struct { cell: i16, value: u16 },
    };

    pub fn printconstraint(self: *const Solver, n: *const Node) void {
        const c = n.top;
        if (c.data.cell >= self.gs) {
            const amt = @intCast(usize, c.data.cell) - self.gs;
            const t = @intToEnum(ConstraintType, @divTrunc(amt, self.gs));
            const cv = amt % self.gs;
            const group = cv / self.gw;
            const value = cv % self.gw;
            print("{any} {any} has value {any}", .{ t, group, value + 1 });
        } else {
            print("cell {any} filled", .{c.data.cell});
        }
    }

    pub fn new(heap: *Allocator, square: usize) !Solver {
        const gw = square * square;
        const gs = gw * gw;
        const numconstraints = gs * 4;
        const numactions = gw * gs;
        const numnodes = numactions * 4 + numconstraints + 1;

        var ret: Solver = undefined;
        ret.heap = heap;
        ret.gs = gs;
        ret.gw = gw;
        ret.s = square;

        const alloc = try heap.alloc(Node, numnodes);
        errdefer (heap.free(alloc));
        ret.nodes = alloc.ptr;

        const stk = try heap.alloc(*Node, gs);
        errdefer (heap.free(stk));
        ret.stack = stk.ptr;
        ret.stackptr = 0;

        const pq = try heap.alloc(*Node, numconstraints);
        errdefer (heap.free(pq));
        ret.pqsize = 0;
        ret.pq = pq.ptr;

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
            constraint.data.cell = @truncate(i16, @bitCast(isize, index));
            constraint.data.value = 0;
            constraint.pqindex = index;
            ret.pqsize += 1;
            ret.pq[index] = constraint;
        }
        prev.right = root;
        root.left = prev;
        prev = root;

        index = 0;
        while (index < numactions) : (index += 1) {
            const value = index / gs;
            const cell = index % gs;
            const row = cell / gw;
            const col = cell % gw;
            const strip = col / square;
            const plank = row / square;
            const sqr = plank * square + strip;

            var actioncell = @bitCast(i16, @truncate(u16, cell));
            var actionvalue = @truncate(u16, value);

            const ac = [_]*Node{ &ret.nodes[cell + 1], &ret.nodes[gs * 1 + row * gw + value + 1], &ret.nodes[gs * 2 + col * gw + value + 1], &ret.nodes[gs * 3 + sqr * gw + value + 1] };
            var prevaction: *Node = undefined;
            var firstaction: *Node = undefined;
            for (ac) |top, idx| {
                const an = &ret.nodes[ptr];
                ptr += 1;

                if (idx > 0) {
                    prevaction.right = an;
                    an.left = prevaction;
                } else firstaction = an;
                prevaction = an;

                an.top = top;
                top.data.value += 1;

                an.up = top.up;
                an.down = top;
                top.up.down = an;
                top.up = an;
                an.data.cell = actioncell;
                an.data.value = actionvalue;
            }
            firstaction.left = prevaction;
            prevaction.right = firstaction;
        }
        return ret;
    }

    fn heap_float_to_top(self: *Solver, idx: usize) void {
        var i = idx;
        while (i > 0) {
            const p = ((i - 1) >> 1);
            self.pq[i].pqindex = p;
            self.pq[p].pqindex = i;
            const t = self.pq[i];
            self.pq[i] = self.pq[p];
            self.pq[p] = t;
            i = p;
        }
    }

    fn heap_float(self: *Solver, idx: usize) void {
        var i = idx;
        while (i > 0) {
            const p = ((i - 1) >> 1);
            if (self.pq[i].data.value >= self.pq[p].data.value)
                return;
            self.pq[i].pqindex = p;
            self.pq[p].pqindex = i;
            const t = self.pq[i];
            self.pq[i] = self.pq[p];
            self.pq[p] = t;
            i = p;
        }
    }

    fn heap_sink(self: *Solver, idx: usize) void {
        var i = idx;
        const max = self.pqsize >> 1;
        while (i < max) {
            var c = (i + 1) * 2;
            if (c == self.pqsize or self.pq[c - 1].data.value < self.pq[c].data.value) c -= 1;
            if (self.pq[i].data.value <= self.pq[c].data.value) return;
            self.pq[i].pqindex = c;
            self.pq[c].pqindex = i;
            const t = self.pq[i];
            self.pq[i] = self.pq[c];
            self.pq[c] = t;
            i = c;
        }
    }

    fn heap_add(self: *Solver, n: *Node) void {
        self.pq[self.pqsize] = n;
        n.pqindex = self.pqsize;
        self.pqsize += 1;
        self.heap_float(self.pqsize - 1);
    }

    fn heap_pop(self: *Solver) ?*Node {
        if (self.pqsize == 0) return null;
        self.pqsize -= 1;
        const ret = self.pq[0];
        if (self.pqsize > 0) {
            self.pq[0] = self.pq[self.pqsize];
            self.heap_sink(0);
        }
        return ret;
    }

    pub fn uncover(self: *Solver, n: *Node) void {
        _ = self;
        var i = n.up;
        while (i != n) : (i = i.up) {
            var j = i.left;
            while (j != i) : (j = j.left) {
                j.up.down = j;
                j.down.up = j;
                j.top.data.value += 1;
                //self.heap_sink(j.top.pqindex);
            }
        }
        n.left.right = n;
        n.right.left = n;
        //self.heap_add(n);
    }

    pub fn cover(self: *Solver, n: *Node) void {
        _ = self;
        //self.heap_float_to_top(n.pqindex);
        //_ = self.heap_pop();
        n.left.right = n.right;
        n.right.left = n.left;
        var i = n.down;
        while (i != n) : (i = i.down) {
            var j = i.right;
            while (j != i) : (j = j.right) {
                j.up.down = j.down;
                j.down.up = j.up;
                j.top.data.value -= 1;
                //self.heap_float(j.top.pqindex);
            }
        }
    }

    pub fn apply(self: *Solver, n: *Node) void {
        self.stack[self.stackptr] = n;
        self.stackptr += 1;

        self.cover(n.top);
        var r = n.right;
        while (r != n) : (r = r.right) {
            self.cover(r.top);
        }
    }

    pub fn undo(self: *Solver) *Node {
        self.stackptr -= 1;
        var n = self.stack[self.stackptr];
        var r = n.left;
        while (r != n) : (r = r.left) {
            self.uncover(r.top);
        }
        self.uncover(n.top);
        return n;
    }

    pub fn find_node(self: *Solver, cell: usize, value: usize) ?*Node {
        var n = self.nodes[0].right;
        while (n != &self.nodes[0]) : (n = n.right) {
            if (n.data.cell == cell) {
                var a = n.down;
                while (a != n) : (a = a.down) {
                    if (a.data.value == value) return a;
                }
            }
        }
        return null;
    }

    pub fn select_node(self: *Solver) ?*Node {
        var n = self.nodes[0].right;
        var ret: ?*Node = null;
        while (n != &self.nodes[0]) : (n = n.right) {
            if (n.data.value == 0) return n;
            if (ret) |r| {
                if (n.data.value < r.data.value)
                    ret = n;
            } else {
                ret = n;
            }
        }
        return ret;
    }

    pub fn search(self: *Solver) bool {
        if (self.select_node()) |con| {
            var n = con.down;
            while (n != con) : (n = n.down) {
                self.apply(n);
                if (self.search())
                    return true;
                _ = self.undo();
            }
        } else return true;
        return false;
    }

    pub fn unwind(self: *Solver) void {
        while (self.stackptr > 0) _ = self.undo();
    }

    pub fn extract(self: *Solver, puzzle: [*]u8) void {
        while (self.stackptr > 0) {
            var n = self.undo();
            const cell = @intCast(usize, @bitCast(u16, n.data.cell));
            var value = @truncate(u8, n.data.value) + 1;
            if (value < 10) {
                value += '0';
            } else value += ('A' - 10);
            puzzle[cell] = value;
        }
    }

    pub fn solve(self: *Solver, puzzle: [*]u8) !bool {
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
            if (val > self.gw) return error.SudokuInvalidCellValue;
            if (val == 0) continue;
            if (self.find_node(index, val - 1)) |n| {
                self.apply(n);
            } else {
                self.unwind();
                return error.SudokuConstraintViolation;
            }
        }
        if (self.search()) {
            self.extract(puzzle);
            return true;
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
    for (grid) |item, index| {
        const col = index % bwidth;
        if (col > 0 and col % 3 == 0) print(" ", .{});
        if (index > 0) {
            if (col == 0) print("\n", .{});
            if (index % (swidth * bwidth) == 0) print("\n", .{});
        }
        print("{any}", .{item});
        h_out.* = item;
    }
    print("\n", .{});
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
var allocator: *Allocator = undefined;

pub fn outputPuzzle(grid: []u8) void {
    for (grid) |item, index| {
        const col = index % bwidth;
        if (col > 0 and col % 3 == 0) print(" ", .{});
        if (index > 0) {
            if (col == 0) print("\n", .{});
            if (index % (swidth * bwidth) == 0) print("\n", .{});
        }
        print("{c}", .{item});
        h_out.* = item;
    }
    print("\n", .{});
}

pub export fn main() void {
    var puzzle = [_]u8{
        0,
        1,
        3,
        5,
        0,
        0,
        4,
        2,
        0,
        0,
        8,
        7,
        0,
        0,
        4,
        0,
        0,
        0,
        0,
        0,
        4,
        0,
        7,
        9,
        6,
        0,
        3,
        0,
        6,
        2,
        0,
        4,
        0,
        5,
        0,
        8,
        0,
        0,
        0,
        0,
        5,
        0,
        1,
        0,
        2,
        0,
        3,
        8,
        0,
        9,
        1,
        0,
        0,
        0,
        0,
        0,
        0,
        9,
        0,
        0,
        8,
        0,
        0,
        7,
        0,
        0,
        8,
        1,
        5,
        0,
        0,
        9,
        8,
        9,
        1,
        0,
        0,
        7,
        2,
        5,
        0,
    };
    if (solve(puzzle[0..])) {
        output(puzzle[0..]);
    }

    print("-----------------------------------\n", .{});

    var fba = std.heap.FixedBufferAllocator.init(__heap[0..]);
    allocator = &fba.allocator();
    const sqsize = 3;
    const gwidth = sqsize * sqsize;
    const gsize = gwidth * gwidth;
    var slv = Solver.new(allocator, sqsize) catch undefined;
    _ = slv;
    var pzl: [gsize]u8 = undefined;
    @memcpy(&pzl, "013500420087004000004079603062040508000050102038091000000900800700815009891007250", gsize);
    //@memcpy(&pzl, "800000000003600000070090200050007000000045700000100030001000068008500010090000400", gsize);
    //@memcpy(&pzl, "002490000590100700700500200003040100000900500005000342001004900049062050006000073", gsize);
    var solved = slv.solve(&pzl) catch false;
    if (solved)
        outputPuzzle(pzl[0..]);
}
