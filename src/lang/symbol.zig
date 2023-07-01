const std = @import("std");

const Span = struct {
    start: usize,
    end: usize,
};

const CONTENT_CAP = 0x8000;
const SPAN_CAP = 0x400;

pub const Symbols = struct {
    alloc: std.mem.Allocator,
    symbols: []u8,
    spans: []Span,

    sym_len: usize,
    len: usize,

    fn init(alloc: std.mem.Allocator) !@This() {
        const symbols = try alloc.alloc(u8, CONTENT_CAP);
        const spans = try alloc.alloc(Span, SPAN_CAP);

        return @This(){
            .alloc = alloc,
            .symbols = symbols,
            .spans = spans,
            .sym_len = 0,
            .len = 0,
        };
    }

    fn deinit(self: *@This()) void {
        self.alloc.free(self.symbols);
        self.alloc.free(self.spans);
    }

    fn intern(self: *@This(), string: []const u8) std.mem.Allocator.Error!usize {
        var i: usize = 0;

        while (i < self.len) {
            const span = self.spans[i];

            if (std.mem.eql(u8, string, self.symbols[span.start..span.end])) {
                return i;
            }

            i += 1;
        }

        if (self.sym_len + string.len > CONTENT_CAP) {
            return std.mem.Allocator.Error.OutOfMemory;
        }

        const sym_end = self.sym_len + string.len;
        @memcpy(self.symbols[self.sym_len..sym_end], string);

        self.spans[i] = Span{
            .start = self.sym_len,
            .end = sym_end,
        };

        self.sym_len = sym_end;
        self.len += 1;

        return i;
    }

    fn resolve(self: *@This(), id: usize) []const u8 {
        var span = self.spans[id];

        return self.symbols[span.start..span.end];
    }
};

test "symbols" {
    var alloc = std.testing.allocator_instance.allocator();
    var symbols = try Symbols.init(alloc);
    defer symbols.deinit();

    const hello = try symbols.intern("hello");
    const world = try symbols.intern("world");
    const welt = try symbols.intern("world");

    try std.testing.expectEqualSlices(u8, symbols.resolve(hello), "hello");
    try std.testing.expectEqualSlices(u8, symbols.resolve(world), "world");
    try std.testing.expectEqualSlices(u8, symbols.resolve(welt), "world");

    try std.testing.expectEqual(world, welt);
}
