const Net = @import("net.zig").Net;
const Signal = @import("../signal.zig").Signal;
pub const Pin = struct { net: *Net, value: Signal };
