const std = @import("std");

const swidth  :u8= 3;
const bwidth : u8 = swidth * swidth;
const bsize : u8 = bwidth * bwidth;

var out : u8 = undefined;
var h_out: *volatile u8 = &out;

pub fn output(grid:[]u8) void {
    for (grid)|item| {
        h_out.* = item;
    }
}

pub fn solve(grid:[]u8) bool {
    var g : [bsize]u8 = undefined;
    @memcpy(g[0..], grid.ptr,bsize);

    var subcell : u8 = bsize;
    var submark : [bwidth+1]u8 = undefined;
    var mark : [bwidth+1]u8 = undefined;
    mark[0] = 0;
    @memset(mark[1..],1,bwidth);

    while (true) {
        var subs : u8 = 0;
        var row : u8 = 0;
        var cell : u8 = 0;
        var rl : u8 = 0;

        while (row < bwidth) : ({row += 1;rl+=bwidth;}) {
            var col : u8 = 0;
            while (col < bwidth) : ({col += 1; cell += 1;}){
                if (g[cell] == 0) {
                    @memset(mark[1..],1,bwidth);
                    var r : u8 = rl;
                    var c : u8 = col;
                    var s : u8 = ((swidth * bwidth) * (row / swidth)) + (swidth * (col / swidth));

                    var x : u8 = 0; while(x<bwidth) : ({x += 1;s += bwidth - swidth;}){
                        var y : u8 = 0; while(y<bwidth) : ({y += 1; r += 1; c += bwidth; s += 1;}){
                            mark[g[r]] = 0;
                            mark[g[c]] = 0;
                            mark[g[s]] = 0;
                        }
                    }

                    var val : u8 = undefined;
                    var count : u8 = 0;
                    for (mark[1..])|item, index|{
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
                        @memcpy(submark[1..],mark[1..],bwidth);
                    }
                }
            }
        }
        if (subs == 0 or subcell >= bsize)
            break;
    }
    if (subcell < bsize) {
        for (submark[1..])|item, index|{
            if (item != 0) {
                g[subcell] = @intCast(u8, index + 1);
                if (solve(g[0..])) {
                    subcell = bsize;
                    break;
                }
            }
        }
    }
    if (subcell >= bsize)
    {
        @memcpy(grid.ptr, g[0..], bsize);
        return true;
    }
    return false;
}

pub export fn main() void {
    var puzzle = [_]u8{0, 1, 3, 5, 0, 0, 4, 2, 0, 0, 8, 7, 0, 0, 4, 0, 0,
                   0, 0, 0, 4, 0, 7, 9, 6, 0, 3, 0, 6, 2, 0, 4, 0, 5,
                   0, 8, 0, 0, 0, 0, 5, 0, 1, 0, 2, 0, 3, 8, 0, 9, 1,
                   0, 0, 0, 0, 0, 0, 9, 0, 0, 8, 0, 0, 7, 0, 0, 8, 1,
                   5, 0, 0, 9, 8, 9, 1, 0, 0, 7, 2, 5, 0};
    if (solve(puzzle[0..])) {
        output(puzzle[0..]);
    }
}
