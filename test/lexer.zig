const std = @import("std");
const Lexer = @import("stats").lang.Lexer;
const Token = Lexer.Token;

test "lexing" {
    const basic_example =
        \\#!/usr/bin/env git-stats
        \\
        \\# a comment!
        \\
        \\bind cloc = `tokei -o json`
        \\
        \\bind code = cloc | `jq .Total.code`
        \\bind comments = cloc | `jq .Total.comments`
        \\
        \\export code, comments
    ;

    var lexer = Lexer.init(basic_example);

    const Case = struct { token: Token, content: []const u8 };
    const cases = [_]Case{
        .{ .token = Token.comment, .content = "#!/usr/bin/env git-stats\n" },
        .{ .token = Token.space, .content = "\n" },
        .{ .token = Token.comment, .content = "# a comment!\n" },
        .{ .token = Token.space, .content = "\n" },
        .{ .token = Token.keyword, .content = "bind" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.ident, .content = "cloc" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.assign, .content = "=" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.exec, .content = "`tokei -o json`" },
        .{ .token = Token.space, .content = "\n\n" },
        .{ .token = Token.keyword, .content = "bind" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.ident, .content = "code" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.assign, .content = "=" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.ident, .content = "cloc" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.pipe, .content = "|" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.exec, .content = "`jq .Total.code`" },
        .{ .token = Token.space, .content = "\n" },
        .{ .token = Token.keyword, .content = "bind" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.ident, .content = "comments" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.assign, .content = "=" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.ident, .content = "cloc" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.pipe, .content = "|" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.exec, .content = "`jq .Total.comments`" },
        .{ .token = Token.space, .content = "\n\n" },
        .{ .token = Token.keyword, .content = "export" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.ident, .content = "code" },
        .{ .token = Token.sep, .content = "," },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.ident, .content = "comments" },
    };

    for (cases) |case| {
        try std.testing.expectEqual(@as(?Token, case.token), try lexer.next());
        try std.testing.expectEqualSlices(u8, case.content, lexer.slice());
    }

    try std.testing.expect(null == try lexer.next());
}
