const std = @import("std");
const sym = @import("sym");

const lang = @import("lang");

fn test_parse_expr(expect: []const u8, input: []const u8) !void {
    var lexer = lang.Lexer.init(input);
    var symbols = try sym.Symbols.init(std.testing.allocator);
    defer symbols.deinit();

    var parser = lang.Parser.init(std.testing.allocator, &symbols, &lexer);
    var expr = try parser.parse_expr();

    defer parser.free(expr);

    const s = try std.fmt.allocPrint(std.testing.allocator, "{}", .{expr});
    defer std.testing.allocator.free(s);

    try std.testing.expectEqualSlices(u8, expect, s);
}

test "example parsing" {
    const example =
        \\#!/usr/bin/env git-stats
        \\
        \\cloc = `tokei -o json`
        \\jq(pattern) = `jq ${pattern}`
        \\
        \\code = cloc | jq(".Total.code")
        \\comments = cloc | jq(".Total.comments")
        \\export code, comments
    ;

    const ast = "(prog " ++
        "(bind (id 0) (shellout \"tokei -o json\")) " ++
        "(bind (id 3) (pipe (id 0) (apply (id 1) \".Total.code\"))) " ++
        "(bind (id 4) (pipe (id 0) (apply (id 1) \".Total.comments\"))) " ++
        "(func (id 1) ((id 2)) (shellout (format \"jq \" (id 2) \"\"))) " ++
        "(export (id 3) (id 3)) " ++
        "(export (id 4) (id 4))" ++
        ")";

    var lexer = lang.Lexer.init(example);
    var symbols = try sym.Symbols.init(std.testing.allocator);
    defer symbols.deinit();

    var parser = lang.Parser.init(std.testing.allocator, &symbols, &lexer);
    var prog = try parser.parse();
    defer parser.free(prog);

    const s = try std.fmt.allocPrint(std.testing.allocator, "{}", .{prog});
    defer std.testing.allocator.free(s);

    try std.testing.expectEqualSlices(u8, ast, s);
}

test "parse: cloc" {
    try test_parse_expr("(id 0)", "cloc\n");
}

test "parse: xyz | cloc" {
    try test_parse_expr("(pipe (id 0) (id 1))", "xyz | cloc\n");
}

test "parse: (xyz | cloc)" {
    try test_parse_expr("(pipe (id 0) (id 1))", "(xyz | cloc)\n");
}

test "parse: xyz(cloc, abc)" {
    try test_parse_expr("(apply (id 0) (id 1) (id 2))", "xyz(cloc, abc)\n");
}

test "parse: \"hello world\" | jq" {
    try test_parse_expr("(pipe \"hello world\" (id 0))", "\"hello world\" | jq");
}

test "parse: \"hello world\" | `sed s:l:r:`" {
    try test_parse_expr("(pipe \"hello world\" (shellout \"sed s:l:r:\"))", "\"hello world\" | `sed s:l:r:`");
}

test "parse: \"hello world\" | ```#!/usr/bin/env python3\nprint(\"hello world\")\n```" {
    try test_parse_expr(
        "(pipe \"hello world\" (script \"/usr/bin/env python3\" \"print(\"hello world\")\n\"))",
        "\"hello world\" | ```#!/usr/bin/env python3\nprint(\"hello world\")\n```\n",
    );
}

test "parse: \"hello world\" | ```/usr/bin/env python3\nprint(\"hello world\")\n```" {
    try test_parse_expr(
        "(pipe \"hello world\" (script \"/usr/bin/env python3\" \"print(\"hello world\")\n\"))",
        "\"hello world\" | ```/usr/bin/env python3\nprint(\"hello world\")\n```\n",
    );
}

test "parse: `jq ${pattern}" {
    try test_parse_expr(
        "(shellout (format \"jq \" (id 0) \"\"))",
        "`jq ${pattern}`",
    );
}

test "parse: \"hello ${subject}\"" {
    try test_parse_expr(
        "(format \"hello \" (id 0) \"\")",
        "\"hello ${subject}\"",
    );
}
