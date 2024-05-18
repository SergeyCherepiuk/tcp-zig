const std = @import("std");
const process = std.process;
const tun = @import("net/tun.zig");
const ip = @import("net/ip.zig");
const tcp = @import("net/tcp.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn main() !void {
    var process_args = process.args();
    const device_name = try parseArgs(&process_args);
    const tun_file = try tun.openTun(device_name);

    var connections = std.AutoHashMap(tcp.Connection, tcp.State).init(allocator);
    defer connections.deinit();

    const buf_size = 1504; // Default MTU + 4 bytes for headers (flags and protocol)
    var buf: [buf_size]u8 = undefined;
    while (true) {
        const bytes = try tun_file.read(&buf);
        const message = buf[0..bytes];

        const ethernet_protocol = (@as(u16, message[2]) << 8) + message[3];
        if (ethernet_protocol != 0x0800) {
            continue;
        }

        const ip_header = ip.Header.new(message[4..24].*);
        if (ip_header.protocol != 0x06) {
            continue;
        }

        const tcp_header = tcp.Header.new(message[24..44].*);

        const connection = tcp.Connection{
            .source_address = ip_header.source_address,
            .source_port = tcp_header.source_port,
            .destination_address = ip_header.destination_address,
            .destination_port = tcp_header.destination_port,
        };

        const entry = try connections.getOrPutValue(connection, tcp.State{});
        const state = entry.value_ptr;
        try state.processPacket(allocator, ip_header, tcp_header, message[44..bytes]);
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
