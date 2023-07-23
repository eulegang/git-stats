const lang = @import("lang");
const std = @import("std");

const Op = lang.Op;
const Inst = lang.Inst;

test "empty" {
    var buf = [_]u8{};
    var inst = Inst.from(&buf);

    try std.testing.expectEqual(inst, Inst.Error.InvalidInst);
}

test "invalid op code" {
    var buf = [_]u8{255};
    var inst = Inst.from(&buf);

    try std.testing.expectEqual(inst, Inst.Error.InvalidInst);
}

test "invalid operand" {
    var buf = [_]u8{1};
    var inst = Inst.from(&buf);
    try std.testing.expectEqual(inst, Inst.Error.InvalidInst);
}

test "test clear op" {
    var buf = [_]u8{0};
    var inst = Inst.from(&buf);

    try std.testing.expectEqual(inst, Inst{ .clear = Op.Clear{} });
    try std.testing.expectEqual((try inst).size(), buf.len);
}

test "test append op" {
    var buf = [_]u8{ 1, 1, 0 };
    var inst = Inst.from(&buf);
    try std.testing.expectEqual(inst, Inst{ .append = Op.Append{ .constant = 1 } });
    try std.testing.expectEqual((try inst).size(), buf.len);
}

test "test reg op" {
    var buf = [_]u8{ 2, 5 };

    var inst = Inst.from(&buf);
    try std.testing.expectEqual(inst, Inst{ .reg = Op.Reg{ .reg = 5 } });
    try std.testing.expectEqual((try inst).size(), buf.len);
}
