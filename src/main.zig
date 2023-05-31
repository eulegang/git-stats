const std = @import("std");

pub fn main() !void {
    var args = std.process.args();

    _ = args.next();
    var filename: [:0]const u8 = undefined;

    if (args.next()) |arg| {
        filename = arg;
    } else {
        const stderr = std.io.getStdErr().writer();
        try stderr.print("need a path to work with\n", .{});
        std.process.exit(1);
    }

    std.debug.print("filename: {s}\n", .{filename});

    var path_buf: [std.fs.MAX_PATH_BYTES]u8 = undefined;
    const path = try std.fs.realpath(filename, &path_buf);

    const file = try std.fs.openFileAbsolute(path, .{ .read = true });
    defer file.close();

    std.debug.print("path: {s}\n", .{path});
}
