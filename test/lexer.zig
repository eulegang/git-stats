const std = @import("std");
const Lexer = @import("lang").Lexer;
const Token = Lexer.Token;

const Case = struct {
    token: Token,
    content: []const u8,
};

test "lexing" {
    const basic_example =
        \\#!/usr/bin/env git-stats
        \\
        \\# a comment!
        \\msg = "hello world"
        \\
        \\cloc = `tokei -o json`
        \\
        \\code = cloc | `jq .Total.code`
        \\comments = cloc \
        \\         | `jq .Total.comments`
        \\
        \\export code, comments
    ;

    var lexer = Lexer.init(basic_example);
    var iter = lexer.iter();

    const cases = [_]Case{
        .{ .token = Token.comment, .content = "#!/usr/bin/env git-stats\n" },
        .{ .token = Token.endline, .content = "\n" },
        .{ .token = Token.comment, .content = "# a comment!\n" },
        .{ .token = Token.ident, .content = "msg" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.assign, .content = "=" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.str, .content = "\"hello world\"" },
        .{ .token = Token.endline, .content = "\n" },
        .{ .token = Token.endline, .content = "\n" },
        .{ .token = Token.ident, .content = "cloc" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.assign, .content = "=" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.exec, .content = "`tokei -o json`" },
        .{ .token = Token.endline, .content = "\n" },
        .{ .token = Token.endline, .content = "\n" },
        .{ .token = Token.ident, .content = "code" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.assign, .content = "=" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.ident, .content = "cloc" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.pipe, .content = "|" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.exec, .content = "`jq .Total.code`" },
        .{ .token = Token.endline, .content = "\n" },
        .{ .token = Token.ident, .content = "comments" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.assign, .content = "=" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.ident, .content = "cloc" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.space, .content = "\\\n" },
        .{ .token = Token.space, .content = "         " },
        .{ .token = Token.pipe, .content = "|" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.exec, .content = "`jq .Total.comments`" },
        .{ .token = Token.endline, .content = "\n" },
        .{ .token = Token.endline, .content = "\n" },
        .{ .token = Token.eksport, .content = "export" },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.ident, .content = "code" },
        .{ .token = Token.comma, .content = "," },
        .{ .token = Token.space, .content = " " },
        .{ .token = Token.ident, .content = "comments" },
    };

    for (cases) |case| {
        std.testing.expectEqual(@as(?Token, case.token), try iter.next()) catch |e| {
            const span = iter.span();
            std.debug.print("line number: {}, content: '{s}'\n", .{
                lexer.lineno(span),
                lexer.resolve(span),
            });
            return e;
        };

        const span = iter.span();
        try std.testing.expectEqualSlices(u8, case.content, lexer.resolve(span));
    }

    try std.testing.expect(null == try iter.next());
}
