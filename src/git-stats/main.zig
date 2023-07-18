const std = @import("std");

const MMap = @import("./mmap.zig").MMap;
pub const lang = @import("lang");
const git = @import("git");

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

    var repo = try git.Repo.open();
    defer repo.deinit();

    const head = try repo.head();
    defer head.deinit();

    var walk = try repo.walk_head();
    defer walk.deinit();

    while (walk.next()) |id| {
        std.debug.print("{}\n", .{id});
    }

    //std.debug.print("head: {}\n", .{head});

    //var lexer = lang.Lexer.init(content.string());
    //while (try lexer.sig()) |token| {
    //    std.debug.print("token: {}\n", .{token});
    //}

    //std.debug.print("content {s}\n", .{content.string()});
}
