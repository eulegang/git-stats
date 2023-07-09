const std = @import("std");

pub const Lexer = struct {
    const Self = @This();
    pub const Error = error{InvalidChar};
    pub const Iter = Iterator;

    pub const Token = enum {
        comment,
        space,

        ident,
        endline,
        assign,
        exec,
        pipe,

        str,

        lparen,
        rparen,

        comma,
        eksport,
        az,
    };

    pub const Span = struct {
        start: usize,
        end: usize,
    };

    content: []const u8,

    pub fn init(content: []const u8) Self {
        return Self{ .content = content };
    }

    pub fn iter(self: *Self) Iter {
        return Iter{
            .lexer = self,
            .hare = 0,
            .pos = 0,
        };
    }

    pub fn resolve(self: *const Self, s: Span) []const u8 {
        return self.content[s.start..s.end];
    }

    pub fn lineno(self: *const Self, s: Span) usize {
        var i: usize = 0;
        var line: usize = 1;

        while (i < s.start) : (i += 1) {
            if (self.content[i] == '\n') {
                line += 1;
            }
        }

        return line;
    }
};

const Iterator = struct {
    const Self = @This();
    const Error = Lexer.Error;

    lexer: *Lexer,
    pos: usize,
    hare: usize,

    pub fn format(
        self: *const Iterator,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        try writer.print("Lexer.Iter {{ .pos = {}, .hare = {} }}", .{ self.pos, self.hare });
    }

    pub fn span(self: *const Self) Lexer.Span {
        return Lexer.Span{
            .start = self.pos,
            .end = self.hare,
        };
    }

    pub fn slice(self: *const Self) []const u8 {
        return self.lexer.content[self.pos..self.hare];
    }

    pub fn snapshot(self: *const Self) Iterator {
        return Iterator{
            .lexer = self.lexer,
            .pos = self.pos,
            .hare = self.hare,
        };
    }

    pub fn sig(self: *Self) Error!?Lexer.Token {
        while (try self.next()) |token| {
            switch (token) {
                Lexer.Token.comment, Lexer.Token.space => continue,
                else => return token,
            }
        }

        return null;
    }

    pub fn next(self: *@This()) Error!?Lexer.Token {
        if (self.hare >= self.lexer.content.len) {
            return null;
        }

        self.pos = self.hare;

        switch (self.lexer.content[self.hare]) {
            '#' => {
                self.eat_line_comment();
                return Lexer.Token.comment;
            },

            ' ', '\t' => {
                self.chomp_space();
                return Lexer.Token.space;
            },

            '\\' => {
                if (self.hare + 1 < self.lexer.content.len) {
                    self.chomp();
                }

                if (self.lexer.content[self.hare] != '\n') {
                    return Error.InvalidChar;
                }

                self.chomp();

                return Lexer.Token.space;
            },

            '\r' => {
                self.chomp();
            },

            '\n' => {
                self.chomp();
                return Lexer.Token.endline;
            },

            '=' => {
                self.chomp();
                return Lexer.Token.assign;
            },

            '`' => {
                self.chomp_exec();
                return Lexer.Token.exec;
            },

            ',' => {
                self.chomp();
                return Lexer.Token.comma;
            },

            '|' => {
                self.chomp();
                return Lexer.Token.pipe;
            },

            '(' => {
                self.chomp();
                return Lexer.Token.lparen;
            },

            ')' => {
                self.chomp();
                return Lexer.Token.rparen;
            },

            'a'...'z' => {
                return self.handle_alpha();
            },

            '\"' => {
                self.chomp_str();
                return Lexer.Token.str;
            },

            else => {
                std.debug.print("invalid char '{s}'\n", .{self.lexer.content[self.hare .. self.hare + 1]});
                return Error.InvalidChar;
            },
        }

        return null;
    }

    fn eat_line_comment(self: *@This()) void {
        while (self.hare < self.lexer.content.len and self.lexer.content[self.hare] != '\n') {
            self.hare += 1;
        }

        if (self.hare < self.lexer.content.len) {
            self.hare += 1;
        }
    }

    fn chomp(self: *@This()) void {
        self.hare += 1;
    }

    fn handle_alpha(self: *@This()) Lexer.Token {
        switch (self.lexer.content[self.hare]) {
            'a' => {
                if (self.is_keyword("as")) {
                    return Lexer.Token.az;
                } else {
                    self.eat_ident();
                    return Lexer.Token.ident;
                }
            },
            'e' => {
                if (self.is_keyword("export")) {
                    return Lexer.Token.eksport;
                } else {
                    self.eat_ident();
                    return Lexer.Token.ident;
                }
            },
            else => {
                self.eat_ident();
                return Lexer.Token.ident;
            },
        }
    }

    fn eat_ident(self: *@This()) void {
        while (self.hare < self.lexer.content.len) {
            switch (self.lexer.content[self.hare]) {
                'a'...'z', 'A'...'Z', '0'...'9', '_' => self.hare += 1,
                else => break,
            }
        }
    }

    fn chomp_space(self: *@This()) void {
        while (self.hare < self.lexer.content.len) {
            switch (self.lexer.content[self.hare]) {
                ' ', '\t', '\r', '\n' => self.hare += 1,
                else => break,
            }
        }
    }

    fn is_keyword(self: *@This(), keyword: []const u8) bool {
        if (self.pos + keyword.len > self.lexer.content.len) {
            return false;
        }

        var hare = self.pos + keyword.len;

        if (!std.mem.eql(u8, self.lexer.content[self.pos..hare], keyword)) {
            return false;
        }

        if (hare == self.lexer.content.len) {
            self.hare = hare;
            return true;
        }

        switch (self.lexer.content[hare]) {
            'a'...'z', 'A'...'Z', '0'...'9', '_' => {
                return false;
            },

            else => {
                self.hare = hare;
                return true;
            },
        }
    }

    fn chomp_exec(self: *@This()) void {
        var hare = self.hare;
        while (self.lexer.content[hare] == '`') {
            hare += 1;
        }

        var count = hare - self.hare;

        if (count < 3) {
            hare = self.hare + 1;
            while (hare < self.lexer.content.len and self.lexer.content[hare] != '`') {
                hare += 1;
            }

            self.hare = hare + 1;
        } else {
            hare = self.hare + 3;
            count = 0;

            while (hare < self.lexer.content.len) : (hare += 1) {
                if (self.lexer.content[hare] == '`') {
                    count += 1;
                } else {
                    count = 0;
                }

                if (count == 3) {
                    break;
                }
            }

            self.hare = hare;
        }
    }

    fn chomp_str(self: *Self) void {
        var count: usize = 0;

        var hare = self.hare;
        hare += 1;

        while (hare < self.lexer.content.len) : (hare += 1) {
            if (self.lexer.content[hare] == '"' and count & 0x01 == 0x00) {
                hare += 1;
                break;
            } else if (self.lexer.content[hare] == '\\') {
                count += 1;
            } else {
                count = 0;
            }
        }

        self.hare = hare;
    }
};
