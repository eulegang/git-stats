const std = @import("std");

const MMap = @import("./mmap.zig").MMap;

const linux = std.os.linux;

pub fn main() !void {
    var args = std.process.args();
    const stderr = std.io.getStdErr().writer();

    _ = args.next();
    var filename: [:0]const u8 = undefined;

    if (args.next()) |arg| {
        filename = arg;
    } else {
        try stderr.print("need a path to work with\n", .{});
        std.process.exit(1);
    }

    const content = try MMap.init(filename);
    defer content.deinit();

    std.debug.print("content {s}\n", .{content.string()});
}
