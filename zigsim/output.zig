const std = @import("std");

const out = std.io.getStdOut();
pub var buf = std.io.bufferedWriter(out.writer());
pub var stdout = buf.writer();
