const std = @import("std");
const ArgIteragor = std.process.ArgIterator;
const ParseArgs = error{NoDeviceName};

pub fn parseArgs(iterator: *ArgIteragor) ParseArgs![]const u8 {
    _ = iterator.skip();
    if (iterator.next()) |device_name| {
        return device_name;
    }
    return error.NoDeviceName;
}
