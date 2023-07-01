const std = @import("std");

pub const Token = enum {
    comment,
    space,
    ident,
    keyword,
    pipe,
    sep,
    assign,
    exec,
};

pub const Error = error{InvalidChar};

pub const Span = struct {
    start: usize,
    end: usize,
};

pub const Lexer = struct {
    content: []const u8,
    pos: usize,
    hare: usize,

    pub fn init(content: []const u8) @This() {
        return @This(){
            .content = content,
            .pos = 0,
            .hare = 0,
        };
    }

    pub fn sig(self: *@This()) Error!?Token {
        while (try self.next()) |token| {
            switch (token) {
                Token.comment, Token.space => continue,
                else => return token,
            }
        }

        return null;
    }

    pub fn next(self: *@This()) Error!?Token {
        if (self.hare >= self.content.len) {
            return null;
        }

        self.pos = self.hare;

        switch (self.content[self.hare]) {
            '#' => {
                self.eat_line_comment();
                return Token.comment;
            },

            ' ', '\t', '\n', '\r' => {
                self.chomp_space();
                return Token.space;
            },

            '=' => {
                self.chomp();
                return Token.assign;
            },

            '`' => {
                self.chomp_exec();
                return Token.exec;
            },

            ',' => {
                self.chomp();
                return Token.sep;
            },

            '|' => {
                self.chomp();
                return Token.pipe;
            },

            'a'...'z' => {
                return self.handle_alpha();
            },

            else => {
                std.debug.print("invalid char '{s}'\n", .{self.content[self.hare .. self.hare + 1]});
                return Error.InvalidChar;
            },
        }

        return null;
    }

    fn eat_line_comment(self: *@This()) void {
        while (self.hare < self.content.len and self.content[self.hare] != '\n') {
            self.hare += 1;
        }

        if (self.hare < self.content.len) {
            self.hare += 1;
        }
    }

    fn chomp(self: *@This()) void {
        self.hare += 1;
    }

    fn handle_alpha(self: *@This()) Token {
        switch (self.content[self.hare]) {
            'b' => {
                if (self.is_keyword("bind")) {
                    return Token.keyword;
                } else {
                    self.eat_ident();
                    return Token.ident;
                }
            },
            'e' => {
                if (self.is_keyword("export")) {
                    return Token.keyword;
                } else {
                    self.eat_ident();
                    return Token.ident;
                }
            },
            else => {
                self.eat_ident();
                return Token.ident;
            },
        }
    }

    fn eat_ident(self: *@This()) void {
        while (self.hare < self.content.len) {
            switch (self.content[self.hare]) {
                'a'...'z', 'A'...'Z', '0'...'9', '_' => self.hare += 1,
                else => break,
            }
        }
    }

    fn chomp_space(self: *@This()) void {
        while (self.hare < self.content.len) {
            switch (self.content[self.hare]) {
                ' ', '\t', '\r', '\n' => self.hare += 1,
                else => break,
            }
        }
    }

    fn is_keyword(self: *@This(), keyword: []const u8) bool {
        if (self.pos + keyword.len > self.content.len) {
            return false;
        }

        var hare = self.pos + keyword.len;

        if (!std.mem.eql(u8, self.content[self.pos..hare], keyword)) {
            return false;
        }

        if (hare == self.content.len) {
            self.hare = hare;
            return true;
        }

        switch (self.content[hare]) {
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
        while (self.content[hare] == '`') {
            hare += 1;
        }

        const count = hare - self.hare;

        if (count < 3) {
            hare = self.hare + 1;
            while (hare < self.content.len and self.content[hare] != '`') {
                hare += 1;
            }

            self.hare = hare + 1;
        } else {}
    }

    pub fn span(self: *const @This()) Span {
        return Span{
            .start = self.pos,
            .end = self.hare,
        };
    }

    pub fn slice(self: *const @This()) []const u8 {
        return self.content[self.pos..self.hare];
    }

    pub fn resolve(self: *const @This(), s: Span) []const u8 {
        return self.content[s.start..s.end];
    }
};

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
