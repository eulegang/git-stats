const lang = @import("lang");
const std = @import("std");

test "disassembler" {
    var prog = lang.Prog{
        .code = &[_]u8{
            0, // clear
            1, // append 0
            0,
            0,
            1, // append 1
            1,
            0,
            3, // set_export 0
            0,
            2, // exit
        },

        .tab = lang.Strtab{
            .content = "helloworld",
            .entries = &[_]lang.Strtab.Entry{
                .{ .ptr = 0, .len = 5 },
                .{ .ptr = 5, .len = 5 },
            },
        },
        .global_count = 0,
        .export_count = 0,
    };

    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();

    try prog.disassemble(buf.writer());

    const expected =
        \\0000 clear
        \\0001 append "hello"
        \\0004 append "world"
        \\0007 set_export 0
        \\0009 exit
        \\
    ;

    try std.testing.expectEqualStrings(expected, buf.items);
}

test "emitter" {
    var emitter = try lang.Emitter.init(std.testing.allocator);
    defer emitter.deinit();

    const id = try emitter.add_export("out");
    try emitter.clear();
    try emitter.append("hello");
    try emitter.append("world");
    try emitter.set_export(id);
    try emitter.exit();

    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();

    var prog = emitter.emit();
    try prog.disassemble(buf.writer());

    const expected =
        \\0000 clear
        \\0001 append "hello"
        \\0004 append "world"
        \\0007 set_export 0
        \\0009 exit
        \\
    ;

    try std.testing.expectEqualStrings(expected, buf.items);
}
