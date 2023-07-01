const std = @import("std");
const Symbols = @import("sym").Symbols;

const lex = @import("./lex.zig");
const Lexer = lex.Lexer;
const Token = lex.Token;

const Export = struct {
    len: usize,
    idents: [64]usize,
};
const Bind = struct {
    ident: usize,
};

const Statement = union(enum) {
    xport: Export,
    bind: Bind,
};

pub const Parser = struct {
    alloc: std.mem.Allocator,
    symbols: *Symbols,

    fn init(alloc: std.mem.Allocator, symbols: *Symbols) @This() {
        return @This(){
            .alloc = alloc,
            .symbols = symbols,
        };
    }

    fn parse(self: *@This(), lexer: *Lexer) void {
        _ = self;
        _ = lexer;
    }
};
