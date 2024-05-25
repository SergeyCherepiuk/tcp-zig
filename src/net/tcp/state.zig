const std = @import("std");
const mem = std.mem;
const fs = std.fs;

const utils = @import("../utils.zig");

const IpHeader = @import("../ip/header.zig").Header;
const TcpHeader = @import("../tcp/header.zig").Header;

pub const State = enum {
    Listen,
    SynSent,
    SynRecived,
    Established,
    FinWait1,
    FinWait2,
    CloseWait,
    Closing,
    LastAck,
    TimeWait,
    Closed,

    pub fn process(
        self: State,
        tun: fs.File,
        ip_header: IpHeader,
        tcp_header: TcpHeader,
        data: []const u8,
    ) usize {
        _ = tun;
        _ = ip_header;
        _ = tcp_header;
        _ = data;

        return switch (self) {
            State.Listen => undefined,
            State.SynSent => undefined,
            State.SynRecived => undefined,
            State.Established => undefined,
            State.FinWait1 => undefined,
            State.FinWait2 => undefined,
            State.CloseWait => undefined,
            State.Closing => undefined,
            State.LastAck => undefined,
            State.TimeWait => undefined,
            State.Closed => 0,
        };
    }
};
