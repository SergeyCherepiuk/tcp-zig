const std = @import("std");
const process = std.process;
const tun = @import("net/tun.zig");
const ip = @import("net/ip.zig");
const tcp = @import("net/tcp.zig");

pub fn main() !void {
    var process_args = process.args();
    const device_name = try parseArgs(&process_args);
    const tun_file = try tun.openTun(device_name);

    const buf_size = 1504; // Default MTU + 4 bytes for headers (flags and protocol)
    var buf: [buf_size]u8 = undefined;
    while (true) {
        const bytes = try tun_file.read(&buf);
        const message = buf[0..bytes];

        const ethernet_protocol = (@as(u16, message[2]) << 8) + message[3];
        if (ethernet_protocol != 0x0800) {
            continue;
        }

        const ip_header = ip.Ip4Header.new(message[4..24].*);
        if (ip_header.protocol != 0x06) {
            continue;
        }

        const tcp_header = tcp.TcpHeader.new(message[24..44].*);
        std.debug.print("{any}\n", .{ip_header});
        std.debug.print("{any}\n", .{tcp_header});
    }
}

const ParseArgs = error{NoDeviceName};

fn parseArgs(iterator: *process.ArgIterator) ParseArgs![]const u8 {
    _ = iterator.skip();
    if (iterator.next()) |device_name| {
        return device_name;
    }
    return error.NoDeviceName;
}
