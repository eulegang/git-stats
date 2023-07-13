const std = @import("std");
const sym = @import("sym");
const Lexer = @import("lexer.zig").Lexer;

const Precedence = enum {
    lowest,
    pipe,
    recover,
    funcall,
    prefix,

    fn perc(token: Lexer.Token) ?Precedence {
        switch (token) {
            .pipe => return .pipe,

            else => return null,
        }
    }
};

pub const Parser = struct {
    pub const Error = Lexer.Error || std.mem.Allocator.Error || sym.Error || error{Expected};
    const Self = @This();

    alloc: std.mem.Allocator,
    symbols: *sym.Symbols,
    lexer: Lexer.Iter,

    pub fn init(alloc: std.mem.Allocator, symbols: *sym.Symbols, lexer: *Lexer) Self {
        return Self{
            .alloc = alloc,
            .symbols = symbols,
            .lexer = lexer.iter(),
        };
    }

    fn subparser(self: *Parser, lexer: *Lexer) Self {
        return Self{
            .alloc = self.alloc,
            .symbols = self.symbols,
            .lexer = lexer.iter(),
        };
    }

    pub fn parse(_: *Self) Error!*Prog {
        unreachable;
    }

    pub fn parse_expr(self: *Self) Error!*Expr {
        return try self.parse_perc(.lowest);
    }

    pub fn free(self: *Self, arg: anytype) void {
        switch (@TypeOf(arg)) {
            Prog => {},

            *Prog => {
                self.free(arg.*);
                self.alloc.destroy(arg);
            },

            Expr => switch (arg) {
                .ident => {},
                .infix => |i| self.free(i),
                .call => |i| self.free(i),
                .str => |i| self.free(i),
                .exec => |i| self.free(i),
            },
            *Expr => {
                self.free(arg.*);
                self.alloc.destroy(arg);
            },

            Infix => {
                self.free(arg.lhs);
                self.free(arg.rhs);
            },

            FunCall => {
                for (arg.args.items) |i| {
                    self.free(i);
                }
                arg.args.deinit();
            },

            Exec => {
                if (arg.interp) |interp| {
                    self.free(interp);
                }
                self.free(arg.content);
            },

            Str => {
                switch (arg) {
                    .lit => |s| self.free(s),
                    .fmt => |f| self.free(f),
                }
            },

            Fmt => {
                for (arg.statics.items) |s| {
                    self.free(s);
                }

                arg.statics.deinit();

                for (arg.exprs.items) |e| {
                    self.free(e);
                }

                arg.exprs.deinit();
            },

            []const u8 => {
                self.alloc.free(arg);
            },

            else => |t| @compileError("parser can not free type of `" ++ @typeName(t) ++ "`"),
        }
    }

    fn parse_prefix(self: *Self) Error!*Expr {
        const token = try self.lexer.sig() orelse return Error.Expected;

        switch (token) {
            .lparen => {
                const expr = try self.parse_perc(.lowest);
                const end_paren = try self.lexer.sig() orelse return Error.Expected;

                if (end_paren != .rparen) {
                    return Error.Expected;
                }

                return expr;
            },

            .ident => {
                const id = try self.symbols.intern(self.lexer.slice());
                var expr = try self.alloc.create(Expr);
                expr.* = Expr{ .ident = id };

                return expr;
            },

            .str => return self.parse_str(self.lexer.slice()),
            .exec => return self.parse_exec(self.lexer.slice()),

            else => |t| {
                std.debug.print("found in prefix: {} {s}\n", .{ t, self.lexer.slice() });

                return Error.Expected;
            },
        }
    }

    fn parse_infix(self: *Self, lhs: *Expr) Error!*Expr {
        var token = try self.lexer.sig() orelse return lhs;

        if (token == .endline) {
            return lhs;
        }

        if (token == .lparen) {
            const ident = switch (lhs.*) {
                .ident => |i| i,
                else => return Error.Expected,
            };

            self.alloc.destroy(lhs);

            var args = std.ArrayList(*Expr).init(self.alloc);

            var hare = self.lexer.snapshot();
            token = try hare.sig() orelse return Error.Expected;

            if (token != .rparen) {
                while (token != .rparen) {
                    const arg = try self.parse_perc(.lowest);
                    try args.append(arg);

                    token = try self.lexer.sig() orelse return Error.Expected;

                    if (token != .rparen and token != .comma) {
                        return Error.Expected;
                    }
                }
            } else {
                self.lexer = hare;
            }

            var res = try self.alloc.create(Expr);
            res.* = Expr{
                .call = FunCall{
                    .ident = ident,
                    .args = args,
                },
            };

            return res;
        }

        if (Precedence.perc(token)) |perc| {
            const op = Infix.Op.from(token);

            const rhs = try self.parse_perc(perc);

            var res = try self.alloc.create(Expr);
            errdefer self.alloc.destroy(res);

            res.* = Expr{
                .infix = Infix{
                    .op = op,
                    .lhs = lhs,
                    .rhs = rhs,
                },
            };

            return res;
        } else {
            return Error.Expected;
        }
    }

    fn parse_perc(self: *Self, prec: Precedence) Error!*Expr {
        var lhs = try self.parse_prefix();
        var hare = self.lexer.snapshot();

        while (true) {
            var token = try hare.sig() orelse break;

            if (token == .endline) {
                break;
            }

            if (token == .lparen) {
                lhs = try self.parse_infix(lhs);
            } else {
                const level = Precedence.perc(token) orelse break;
                if (@enumToInt(prec) >= @enumToInt(level)) {
                    break;
                }

                lhs = try self.parse_infix(lhs);
            }
        }

        return lhs;
    }

    fn parse_str(self: *Self, slice: []const u8) Error!*Expr {
        var str = try self.interp_str(slice[1 .. slice.len - 1]);

        var res = try self.alloc.create(Expr);
        res.* = Expr{ .str = str };
        return res;
    }

    fn parse_exec(self: *Self, slice: []const u8) Error!*Expr {
        if (slice.len < 3) {
            std.debug.print("slice: \"{s}\"\n", .{slice});
            return Error.Expected;
        }

        var res = try self.alloc.create(Expr);
        errdefer self.alloc.destroy(res);

        var i: usize = 0;

        if (slice[1] != '`' and slice[2] != '`') {
            var str = try self.interp_str(slice[1 .. slice.len - 1]);

            res.* = Expr{
                .exec = Exec{
                    .interp = null,
                    .content = str,
                },
            };
        } else {
            i = 3;
            var nl = while (i < slice.len) : (i += 1) {
                if (slice[i] == '\n') {
                    break i;
                }
            } else {
                return Error.Expected;
            };

            const interp_section = if (slice[3] == '#' and slice[4] == '!')
                slice[5..nl]
            else
                slice[3..nl];

            var interp = try self.interp_str(interp_section);
            errdefer self.free(interp);

            var content = try self.interp_str(slice[nl + 1 .. slice.len - 2]);

            res.* = Expr{
                .exec = Exec{
                    .interp = interp,
                    .content = content,
                },
            };
        }

        return res;
    }

    fn interp_str(self: *Self, slice: []const u8) Error!Str {
        var fmt = false;
        var i: usize = 0;
        var dollar = false;

        while (i < slice.len) : (i += 1) {
            if (dollar) {
                switch (slice[i]) {
                    '{' => {
                        fmt = true;
                        break;
                    },

                    '$' => {
                        dollar = false;
                    },

                    else => {
                        return Error.Expected;
                    },
                }
            } else {
                if (slice[i] == '$') {
                    dollar = true;
                }
            }
        }

        if (fmt) {
            return build_dyn_str(self, slice);
        } else {
            return build_static_str(self.alloc, slice);
        }
    }
};

pub const Prog = struct {
    binds: std.ArrayList(Bind),
    exports: std.ArrayList(Export),

    pub fn format(
        self: *const Prog,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("(prog\n", .{});

        for (self.binds.items) |bind| {
            try writer.print("  {}", .{bind});
        }

        for (self.exports.items) |e| {
            try writer.print("  {}", .{e});
        }

        try writer.print(")\n", .{});
    }
};

pub const Expr = union(enum) {
    ident: u64,
    infix: Infix,
    call: FunCall,
    str: Str,
    exec: Exec,

    pub fn format(e: *const Expr, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (e.*) {
            .ident => |i| try writer.print("(id {})", .{i}),
            .infix => |i| try writer.print("{}", .{i}),
            .call => |i| try writer.print("{}", .{i}),
            .str => |i| try writer.print("{}", .{i}),
            .exec => |i| try writer.print("{}", .{i}),
        }
    }
};

pub const Infix = struct {
    pub const Op = enum {
        pipe,

        fn from(token: Lexer.Token) Op {
            switch (token) {
                .pipe => return .pipe,

                else => unreachable,
            }
        }
    };

    op: Op,
    lhs: *Expr,
    rhs: *Expr,

    pub fn format(
        self: *const Infix,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        const op = switch (self.op) {
            .pipe => "pipe",
        };

        try writer.print("({s} {} {})", .{ op, self.lhs, self.rhs });
    }
};

pub const Exec = struct {
    interp: ?Str,
    content: Str,

    pub fn format(
        self: *const Exec,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        if (self.interp) |interp| {
            try writer.print("(script {} {})", .{ interp, self.content });
        } else {
            try writer.print("(shellout {})", .{self.content});
        }
    }
};

pub const FunCall = struct {
    ident: u64,
    args: std.ArrayList(*Expr),

    pub fn format(
        self: *const FunCall,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("(apply (id {})", .{self.ident});
        for (self.args.items) |expr| {
            try writer.print(" {}", .{expr});
        }

        try writer.print(")", .{});
    }
};

/// A portion of an export statement
pub const Export = struct {
    /// Inner variable to output
    inner: u64,

    /// Outer variable that represents a value
    outer: u64,

    pub fn format(
        self: *const Export,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("(export (id {}) (id {}))", .{ self.inner, self.outer });
    }
};

/// A binding
pub const Bind = struct {
    /// The symbol to bind an expression to
    name: u64,

    /// An expression to be evaluated
    expr: Expr,

    pub fn format(
        self: *const Bind,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("(bind (id {}) {})", .{ self.name, self.expr });
    }
};

const Str = union(enum) {
    lit: []const u8,
    fmt: Fmt,

    pub fn format(
        self: *const Str,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        switch (self.*) {
            .lit => |s| try writer.print("\"{s}\"", .{s}),
            .fmt => |f| try writer.print("{}", .{f}),
        }
    }
};

const Fmt = struct {
    statics: std.ArrayList([]const u8),
    exprs: std.ArrayList(*Expr),

    pub fn format(
        self: *const Fmt,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        var i: usize = 0;
        try writer.print("(format", .{});

        while (i < self.statics.items.len) : (i += 1) {
            try writer.print(" \"{s}\"", .{self.statics.items[i]});
            if (i < self.exprs.items.len) {
                try writer.print(" {}", .{self.exprs.items[i]});
            }
        }

        try writer.print(")", .{});
    }
};

fn build_static_str(alloc: std.mem.Allocator, slice: []const u8) Parser.Error!Str {
    var buf = try alloc.alloc(u8, slice.len);
    errdefer alloc.free(buf);
    var escaped = false;
    var i: usize = 0;

    for (slice) |byte| {
        if (byte == '$') {
            escaped = true;
        } else if (escaped) {
            if (byte == '$') {
                buf[i] = byte;
                i += 1;
            }
            escaped = false;
        } else {
            buf[i] = byte;
            i += 1;
        }
    }

    if (i < slice.len) {
        _ = alloc.resize(buf, i);
    }

    return Str{ .lit = buf };
}

fn build_dyn_str(parser: *Parser, slice: []const u8) Parser.Error!Str {
    var alloc = parser.alloc;
    var statics = std.ArrayList([]const u8).init(alloc);
    errdefer statics.deinit();

    errdefer for (statics.items) |s| {
        alloc.free(s);
    };

    var exprs = std.ArrayList(*Expr).init(alloc);
    errdefer exprs.deinit();

    errdefer for (exprs.items) |e| {
        parser.free(e);
    };

    var scratch = try alloc.alloc(u8, slice.len);
    defer alloc.free(scratch);

    var i: usize = 0;
    var scratch_next: usize = 0;
    var dollar = false;

    while (i < slice.len) : (i += 1) {
        if (dollar) {
            switch (slice[i]) {
                '$' => {
                    scratch[scratch_next] = '$';
                    scratch_next += 1;
                },
                '{' => {
                    i += 1;
                    if (i >= slice.len)
                        return Parser.Error.Expected;

                    var j = i;

                    while (j < slice.len) : (j += 1) {
                        if (slice[j] == '}')
                            break;
                    }

                    if (j == slice.len)
                        return Parser.Error.Expected;

                    const src = scratch[0..scratch_next];
                    var buf = try alloc.alloc(u8, scratch_next);
                    scratch_next = 0;

                    @memcpy(buf, src);
                    try statics.append(buf);

                    var lexer = Lexer.init(slice[i..j]);
                    var sub = parser.subparser(&lexer);
                    var expr = try sub.parse_expr();
                    try exprs.append(expr);

                    i = j + 1;
                },
                else => return Parser.Error.Expected,
            }
        } else {
            switch (slice[i]) {
                '$' => {
                    dollar = true;
                },

                else => {
                    scratch[scratch_next] = slice[i];
                    scratch_next += 1;
                },
            }
        }
    }

    const src = scratch[0..scratch_next];
    var buf = try alloc.alloc(u8, scratch_next);

    @memcpy(buf, src);
    try statics.append(buf);

    return Str{
        .fmt = Fmt{
            .statics = statics,
            .exprs = exprs,
        },
    };
}
