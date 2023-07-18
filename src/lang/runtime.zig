const std = @import("std");
const sym = @import("sym");

const StoreInst = struct {
    ident: u16,
    str: []const u8,
};

const RunInst = struct {
    ident: u16,
    str: u16,
};

const AppendInst = struct {
    ident: u16,
    str: u16,
};

pub const Inst = union(enum) {
    const Store = StoreInst;
    const Run = RunInst;
    const Append = AppendInst;

    store: Store,
    run: Run,
    append: Append,
};

const Runtime = struct {
    const Self = @This();

    pub const Error = error{
        InvalidReg,
    };

    alloc: std.mem.Allocator,
    symbols: sym.Symbols,

    pub fn init(alloc: std.mem.Allocator, symbols: *sym.Symbols) Self {
        return Self{
            .alloc = alloc,
            .symbols = symbols,
        };
    }

    pub fn run(self: *Self, arg: anytype) Error!void {
        switch (@TypeOf(arg)) {
            []Inst => {
                for (arg) |inst| {
                    try self.run(inst);
                }
            },

            Inst => switch (arg) {
                .store => {},
                .run => {},
                .append => {},
            },

            else => |t| @compileError("Runtime does not interpret `" ++ @typeName(t) ++ "`s"),
        }
    }
};
