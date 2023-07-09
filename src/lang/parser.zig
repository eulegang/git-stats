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

    pub fn parse(_: *Self) Error!*Prog {
        unreachable;
    }

    pub fn parse_expr(self: *Self) Error!*Expr {
        return try self.parse_perc(.lowest);
    }

    pub fn free(self: *Self, arg: anytype) void {
        switch (@TypeOf(arg)) {
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
        var buf = try self.alloc.alloc(u8, slice.len - 2);
        var escaped = false;
        var i: usize = 0;
        for (slice[1 .. slice.len - 1]) |byte| {
            if (byte == '\\') {
                escaped = true;
            } else if (escaped) {
                escaped = false;
            } else {
                buf[i] = byte;
                i += 1;
            }
        }

        var res = try self.alloc.create(Expr);
        res.* = Expr{ .str = buf };
        return res;
    }

    fn parse_exec(self: *Self, slice: []const u8) Error!*Expr {
        if (slice.len < 3) {
            std.debug.print("slice: \"{s}\"\n", .{slice});
            return Error.Expected;
        }

        var buf = try self.alloc.alloc(u8, slice.len - 2);
        errdefer self.alloc.free(buf);

        var res = try self.alloc.create(Expr);
        errdefer self.alloc.destroy(res);

        var escaped = false;
        var i: usize = 0;

        if (slice[1] != '`' and slice[2] != '`') {
            for (slice[1 .. slice.len - 1]) |byte| {
                if (byte == '\\') {
                    escaped = true;
                } else if (escaped) {
                    escaped = false;
                } else {
                    buf[i] = byte;
                    i += 1;
                }
            }

            res.* = Expr{
                .exec = Exec{
                    .interp = null,
                    .content = buf,
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

            var interp = try self.alloc.alloc(u8, interp_section.len);
            errdefer self.alloc.free(interp);
            @memcpy(interp, interp_section);

            i = 0;
            for (slice[nl + 1 .. slice.len - 2]) |byte| {
                if (byte == '\\') {
                    escaped = true;
                } else if (escaped) {
                    escaped = false;
                } else {
                    buf[i] = byte;
                    i += 1;
                }
            }

            _ = self.alloc.resize(buf, i);

            res.* = Expr{
                .exec = Exec{
                    .interp = interp,
                    .content = buf[0..i],
                },
            };
        }

        return res;
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

        for (self.binds) |bind| {
            try writer.print("  {}", .{bind});
        }

        for (self.exports) |e| {
            try writer.print("  {}", .{e});
        }

        try writer.print(")\n", .{});
    }
};

pub const Expr = union(enum) {
    ident: u64,
    infix: Infix,
    call: FunCall,
    str: []const u8,
    exec: Exec,

    pub fn format(e: *const Expr, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (e.*) {
            .ident => |i| try writer.print("(id {})", .{i}),
            .infix => |i| try writer.print("{}", .{i}),
            .call => |i| try writer.print("{}", .{i}),
            .str => |i| try writer.print("\"{s}\"", .{i}),
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
    interp: ?[]const u8,
    content: []const u8,

    pub fn format(
        self: *const Exec,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        if (self.interp) |interp| {
            try writer.print("(script \"{s}\" \"{s}\")", .{ interp, self.content });
        } else {
            try writer.print("(shellout \"{s}\")", .{self.content});
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
        try writer.print("(export id[{}] id[{}])", .{ self.inner, self.outer });
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
        try writer.print("(bind id[{}] {})", self.name, self.expr);
    }
};
