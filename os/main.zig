const std = @import("std");
const builtin = @import("builtin");
const prt = builtin.os.tag != std.Target.Os.Tag.freestanding;
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

var out: u8 = undefined;
var h_out: *volatile u8 = &out;

pub fn outputPuzzle(sqr: usize, grid: []u8) void {
    const numvals = sqr * sqr;
    for (grid) |item, index| {
        const col = index % numvals;
        if (col > 0 and col % sqr == 0) print(" ", .{});
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

    const puzzles = [_][]const u8{ "013500420087004000004079603062040508000050102038091000000900800700815009891007250", "002490000590100700700500200003040100000900500005000342001004900049062050006000073", "800000000003600000070090200050007000000045700000100030001000068008500010090000400" };
    for (puzzles) |puzzle, index| {
        var pzl: [gsize]u8 = undefined;
        std.mem.copy(u8, pzl[0..], puzzle);
        if (solver.solve(&pzl) catch false) {
            if (index > 0) {
                print("----------------------------------------\n", .{});
            }
            outputPuzzle(sqsize, pzl[0..]);
        }
    }
}
