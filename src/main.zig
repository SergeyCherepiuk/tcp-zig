const std = @import("std");
const process = std.process;

const tun = @import("net/tun.zig");
const utils = @import("net/utils.zig");

const IpHeader = @import("net/ip.zig").Header;
const TcpHeader = @import("net/tcp.zig").Header;
const TcpConnection = @import("net/tcp.zig").Connection;
const TcpState = @import("net/tcp.zig").State;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn main() !void {
    var process_args = process.args();
    const device_name = try parseArgs(&process_args);

    const tun_file = try tun.openTun(device_name);
    defer tun_file.close();

    var connections = std.AutoHashMap(TcpConnection, TcpState).init(allocator);
    defer connections.deinit();

    const buf_size = 1504; // Default MTU + 4 bytes for headers (flags and protocol)
    var buf: [buf_size]u8 = undefined;
    while (true) {
        const bytes_read = try tun_file.read(&buf);
        const message = buf[0..bytes_read];
        var bytes_parsed: usize = 0;

        const ethernet_protocol = utils.intFromBytes(u16, message[2..4]);
        if (ethernet_protocol != 0x0800) {
            continue;
        }
        bytes_parsed += 4;

        const ip_header_union = IpHeader.fromBytes(message[bytes_parsed..]);
        if (ip_header_union.header.protocol != 0x06) {
            continue;
        }
        bytes_parsed += ip_header_union.bytes_read;

        const tcp_header_union = TcpHeader.fromBytes(message[bytes_parsed..]);
        bytes_parsed += tcp_header_union.bytes_read;

        const connection = TcpConnection{
            .source_address = ip_header_union.header.source_address,
            .source_port = tcp_header_union.header.source_port,
            .destination_address = ip_header_union.header.destination_address,
            .destination_port = tcp_header_union.header.destination_port,
        };

        const entry = try connections.getOrPutValue(connection, TcpState.Listen);
        const state = entry.value_ptr;
        _ = state.process(
            tun_file,
            ip_header_union.header,
            tcp_header_union.header,
            message[bytes_parsed..],
        );
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
