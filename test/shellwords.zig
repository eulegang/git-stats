const std = @import("std");
const lang = @import("lang");

test "basic command" {
    var args_buf: [256][]const u8 = undefined;
    var cmd: []const u8 = "ls";
    var args = lang.shellwords(cmd, &args_buf);

    try std.testing.expectEqual(args.len, 1);
    try std.testing.expectEqualStrings(args[0], "ls");
}

test "basic echo" {
    var args_buf: [256][]const u8 = undefined;
    var cmd: []const u8 = "echo hello world";
    var args = lang.shellwords(cmd, &args_buf);

    try std.testing.expectEqual(args.len, 3);

    try std.testing.expectEqualStrings(args[0], "echo");
    try std.testing.expectEqualStrings(args[1], "hello");
    try std.testing.expectEqualStrings(args[2], "world");
}

test "basic quote" {
    var args_buf: [256][]const u8 = undefined;
    var cmd: []const u8 = "echo 'hello world'";
    var args = lang.shellwords(cmd, &args_buf);

    try std.testing.expectEqual(args.len, 2);

    try std.testing.expectEqualStrings(args[0], "echo");
    try std.testing.expectEqualStrings(args[1], "hello world");
}
