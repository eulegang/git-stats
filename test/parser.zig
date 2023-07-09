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

    //try std.testing.expectFmt(expect, "{}", .{expr});
}

//test "example parsing" {
//    const example =
//        \\#!/usr/bin/env git-stats
//        \\
//        \\cloc = `tokei -o json`
//        \\jq pattern = `jq ${pattern}`
//        \\
//        \\code = cloc | jq ".Total.code"
//        \\comments = cloc | jq ".Total.comments"
//        \\export code, comments
//    ;
//
//    var lexer = lang.Lexer.init(example);
//    var symbols = try sym.Symbols.init(std.testing.allocator);
//    defer symbols.deinit();
//
//    var parser = lang.Parser.init(std.testing.allocator, &symbols);
//
//    _ = parser;
//    _ = lexer;
//}

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
