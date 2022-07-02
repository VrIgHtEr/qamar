const std = @import("std");
const builtin = @import("builtin");
const prt = builtin.os.tag != std.Target.Os.Tag.freestanding;
const Allocator = std.mem.Allocator;
var __heap: [1048576]u8 = undefined;
const sqsize = 3;
var solver = SolverType(sqsize).init();

fn print(comptime fmt: []const u8, args: anytype) void {
    if (prt) std.debug.print(fmt, args);
}

fn NarrowType(comptime x: usize) type {
    if (x <= 256) {
        return u8;
    } else if (x <= 65536) {
        return u16;
    } else if (x <= 0x100000000) {
        return u32;
    } else return u64;
}

fn SolverType(comptime square: usize) type {
    const num_values = square * square;
    const num_cells = num_values * num_values;
    const num_constraints = num_cells * 4;
    const num_actions = num_cells * num_values;
    const num_action_nodes = num_actions * 4;
    const num_nodes = num_constraints + num_action_nodes + 1;
    const start_constraints = 1;
    const end_constraints = num_constraints + 1;

    const N = NarrowType(num_nodes + 1);
    const C = NarrowType(num_cells + 1);
    const V = NarrowType(num_values + 1);

    const Node = packed struct { top: N, up: N, down: N, left: N, right: N, cell: C, value: V, _reserved: u32 };

    return struct {
        stackptr: C,
        stack: [num_cells]N,
        nodes: [num_nodes]Node,

        pub fn init() @This() {
            @setEvalBranchQuota(65536);
            comptime var ret: @This() = undefined;
            ret.stackptr = 0;
            comptime var i = 0;
            inline while (i < num_cells) : (i += 1)
                ret.stack[i] = 0;

            ret.nodes[0] = .{ .top = 0, .up = 0, .down = 0, .cell = 0, .value = 0, .left = 0, .right = 0, ._reserved = 0 };
            i = 0;
            inline while (i < num_constraints) : (i += 1) {
                const idx = @intCast(N, i + start_constraints);
                ret.nodes[idx - 1].right = idx;
                ret.nodes[idx].top = idx;
                ret.nodes[idx].up = idx;
                ret.nodes[idx].down = idx;
                ret.nodes[idx].left = idx - 1;
                if (i < num_cells) {
                    ret.nodes[idx].cell = i;
                } else {
                    ret.nodes[idx].cell = num_cells;
                }
                ret.nodes[idx].value = num_values;
            }
            ret.nodes[0].left = num_constraints;
            ret.nodes[num_constraints].right = 0;

            i = 0;
            inline while (i < num_actions) : (i += 1) {
                const idx = @intCast(N, i * 4 + end_constraints);

                const value = i / num_cells;
                const cell = i % num_cells;
                const row = cell / num_values;
                const col = cell % num_values;
                const strip = col / square;
                const plank = row / square;
                const sqr = plank * square + strip;

                const actioncell = @intCast(C, cell);
                const actionvalue = @intCast(V, value);

                const ac = [_]N{ @intCast(N, start_constraints + cell), @intCast(N, start_constraints + num_cells + row * num_values + value), @intCast(N, start_constraints + num_cells * 2 + col * num_values + value), @intCast(N, start_constraints + num_cells * 3 + sqr * num_values + value) };

                comptime var anindex: usize = 0;
                inline while (anindex < 4) : (anindex += 1) {
                    const anidx = @intCast(N, idx + anindex);
                    ret.nodes[anidx].top = ac[anindex];
                    ret.nodes[anidx].down = ac[anindex];
                    ret.nodes[anidx].up = ret.nodes[ac[anindex]].up;
                    ret.nodes[ret.nodes[ac[anindex]].up].down = anidx;
                    ret.nodes[ac[anindex]].up = anidx;
                    if (anindex == 0) {
                        ret.nodes[anidx].left = idx + 3;
                        ret.nodes[idx + 3].right = anidx;
                    } else {
                        ret.nodes[anidx - 1].right = anidx;
                        ret.nodes[anidx].left = anidx - 1;
                    }
                    ret.nodes[anidx].cell = actioncell;
                    ret.nodes[anidx].value = actionvalue;
                }
            }
            return ret;
        }

        pub fn uncover(self: *@This(), n: N) void {
            var i = self.nodes[n].up;
            while (i != n) : (i = self.nodes[i].up) {
                var j = self.nodes[i].left;
                while (j != i) : (j = self.nodes[j].left) {
                    self.nodes[self.nodes[j].up].down = j;
                    self.nodes[self.nodes[j].down].up = j;
                    self.nodes[self.nodes[j].top].value += 1;
                }
            }
            self.nodes[self.nodes[n].left].right = n;
            self.nodes[self.nodes[n].right].left = n;
        }

        pub fn cover(self: *@This(), n: N) void {
            self.nodes[self.nodes[n].left].right = self.nodes[n].right;
            self.nodes[self.nodes[n].right].left = self.nodes[n].left;
            var i = self.nodes[n].down;
            while (i != n) : (i = self.nodes[i].down) {
                var j = self.nodes[i].right;
                while (j != i) : (j = self.nodes[j].right) {
                    self.nodes[self.nodes[j].up].down = self.nodes[j].down;
                    self.nodes[self.nodes[j].down].up = self.nodes[j].up;
                    self.nodes[self.nodes[j].top].value -= 1;
                }
            }
        }

        pub fn apply(self: *@This(), n: N) void {
            self.stack[self.stackptr] = n;
            self.stackptr += 1;

            self.cover(self.nodes[n].top);
            var r = self.nodes[n].right;
            while (r != n) : (r = self.nodes[r].right) {
                self.cover(self.nodes[r].top);
            }
        }

        pub fn undo(self: *@This()) N {
            self.stackptr -= 1;
            var n = self.stack[self.stackptr];
            var r = self.nodes[n].left;
            while (r != n) : (r = self.nodes[r].left) {
                self.uncover(self.nodes[r].top);
            }
            self.uncover(self.nodes[n].top);
            return n;
        }

        pub fn find_node(self: *@This(), cell: C, value: V) ?N {
            var n = self.nodes[0].right;
            while (n != 0) : (n = self.nodes[n].right) {
                if (self.nodes[n].cell == cell) {
                    var a = self.nodes[n].down;
                    while (a != n) : (a = self.nodes[a].down) {
                        if (self.nodes[a].value == value) return a;
                    }
                }
            }
            return null;
        }

        pub fn select_node(self: *@This()) ?N {
            var n = self.nodes[0].right;
            var ret: ?N = null;
            while (n != 0) : (n = self.nodes[n].right) {
                if (self.nodes[n].value == 0) return n;
                if (ret) |r| {
                    if (self.nodes[n].value < self.nodes[r].value)
                        ret = n;
                } else {
                    ret = n;
                }
            }
            return ret;
        }

        pub fn search(self: *@This()) bool {
            if (self.select_node()) |con| {
                var n = self.nodes[con].down;
                while (n != con) : (n = self.nodes[n].down) {
                    self.apply(n);
                    if (self.search())
                        return true;
                    _ = self.undo();
                }
            } else return true;
            return false;
        }

        pub fn unwind(self: *@This()) void {
            while (self.stackptr > 0) _ = self.undo();
        }

        pub fn extract(self: *@This(), puzzle: [*]u8) void {
            while (self.stackptr > 0) {
                var n = self.undo();
                const cell = self.nodes[n].cell;
                var value = @truncate(u8, self.nodes[n].value) + 1;
                if (value < 10) {
                    value += '0';
                } else value += ('A' - 10);
                puzzle[cell] = value;
            }
        }

        pub fn solve(self: *@This(), puzzle: [*]u8) !bool {
            self.unwind();
            var index: C = 0;
            while (index < num_cells) : (index += 1) {
                const char = puzzle[index];
                var val: V = 0;
                if (char >= '0' and char <= '9') {
                    val = char - '0';
                } else if (char >= 'a' and char <= 'z') {
                    val = char - 'a' + 10;
                } else if (char >= 'A' and char <= 'Z') {
                    val = char - 'A' + 10;
                }
                if (val > num_values) return error.SudokuInvalidCellValue;
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
            self.unwind();
            return error.SudokuUnsolvable;
        }
    };
}

const Solver = struct {
    heap: *Allocator,
    nodes: [*]Node,
    stack: [*]*Node,
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

    pub fn free(self: *Solver) void {
        self.heap.free(self.nodes[0..(1 + self.gs * 4 + self.gs * self.gw * 4)]);
        self.nodes = undefined;

        self.heap.free(self.stack[0..self.gs]);
        self.stack = undefined;

        self.heap = undefined;
    }

    pub fn new(heap: *Allocator, comptime square: usize) !Solver {
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

    pub fn uncover(self: *Solver, n: *Node) void {
        _ = self;
        var i = n.up;
        while (i != n) : (i = i.up) {
            var j = i.left;
            while (j != i) : (j = j.left) {
                j.up.down = j;
                j.down.up = j;
                j.top.data.value += 1;
            }
        }
        n.left.right = n;
        n.right.left = n;
    }

    pub fn cover(self: *Solver, n: *Node) void {
        _ = self;
        n.left.right = n.right;
        n.right.left = n.left;
        var i = n.down;
        while (i != n) : (i = i.down) {
            var j = i.right;
            while (j != i) : (j = j.right) {
                j.up.down = j.down;
                j.down.up = j.up;
                j.top.data.value -= 1;
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
        return error.SudokuUnsolvable;
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

pub fn outputPuzzle(sqr: usize, grid: []u8) void {
    const numvals = sqr * sqr;
    for (grid) |item, index| {
        const col = index % numvals;
        if (col > 0 and col % swidth == 0) print(" ", .{});
        if (index > 0) {
            if (col == 0) print("\n", .{});
            if (index % (sqr * numvals) == 0) print("\n", .{});
        }
        print("{c}", .{item});
        h_out.* = item;
    }
    print("\n", .{});
}
pub export fn main() void {
    const gwidth = sqsize * sqsize;
    const gsize = gwidth * gwidth;

    var pzl: [gsize]u8 = undefined;
    @memcpy(&pzl, "013500420087004000004079603062040508000050102038091000000900800700815009891007250", gsize);
    //    //@memcpy(&pzl, "800000000003600000070090200050007000000045700000100030001000068008500010090000400", gsize);
    //    //@memcpy(&pzl, "002490000590100700700500200003040100000900500005000342001004900049062050006000073", gsize);
    //
    //    var puzzle: [gsize]u8 = undefined;
    //    for (pzl) |char, index| {
    //        if (char >= '0' and char <= '9') {
    //            puzzle[index] = char - '0';
    //        } else if (char >= 'a' and char <= 'z') {
    //            puzzle[index] = char - 'a' + 10;
    //        } else if (char >= 'Z' and char <= 'Z') {
    //            puzzle[index] = char - 'A' + 10;
    //        }
    //    }
    //
    //    if (solve(puzzle[0..])) {
    //        output(puzzle[0..]);
    //    }
    //
    //    print("-----------------------------------\n", .{});
    //
    //    var fba = std.heap.FixedBufferAllocator.init(__heap[0..]);
    //    var allocator = fba.allocator();
    //    var slv: ?Solver = Solver.new(&allocator, sqsize) catch null;
    //    if (slv) |_| {
    //        defer (slv.?.free());
    //        var solved = slv.?.solve(&pzl) catch false;
    //        if (solved)
    //            outputPuzzle(pzl[0..]);
    //    }

    if (solver.solve(&pzl) catch false) {
        outputPuzzle(sqsize, pzl[0..]);
    }
}
