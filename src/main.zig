const std = @import("std");
const process = std.process;
const tun = @import("net/tun.zig");
const ip = @import("net/ip.zig");
const tcp = @import("net/tcp.zig");
const utils = @import("net/utils.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn main() !void {
    var process_args = process.args();
    const device_name = try parseArgs(&process_args);

    const tun_file = try tun.openTun(device_name);
    defer tun_file.close();

    var connections = std.AutoHashMap(tcp.Connection, tcp.State).init(allocator);
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

        const iph_union = ip.Header.parse(message[bytes_parsed..]);
        if (iph_union.header.protocol != 0x06) {
            continue;
        }
        bytes_parsed += iph_union.bytes_read;

        const tcph_union = tcp.Header.parse(message[bytes_parsed..]);
        bytes_parsed += tcph_union.bytes_read;

        const connection = tcp.Connection{
            .source_address = iph_union.header.source_address,
            .source_port = tcph_union.header.source_port,
            .destination_address = iph_union.header.destination_address,
            .destination_port = tcph_union.header.destination_port,
        };

        const entry = try connections.getOrPutValue(connection, tcp.State.Listen);
        const state = entry.value_ptr;
        _ = state.process(
            tun_file,
            iph_union.header,
            tcph_union.header,
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
