const std = @import("std");
const lang = @import("lang");

test "simple execution example" {
    var emitter = try lang.Emitter.init(std.testing.allocator);
    defer emitter.deinit();

    const english_id = try emitter.add_export("english");
    const german_id = try emitter.add_export("german");

    try emitter.clear();
    try emitter.append_const("hello");
    try emitter.append_const(", ");
    try emitter.append_const("world");
    try emitter.push_scratch();
    try emitter.set_export(english_id);
    try emitter.clear();
    try emitter.append_const("hallo, welt");
    try emitter.push_scratch();
    try emitter.set_export(german_id);
    try emitter.exit();

    var vm = try lang.Vm.init(std.testing.allocator);
    defer vm.deinit();

    var prog = emitter.emit();

    try vm.run(&prog);

    try std.testing.expectEqualStrings("hello, world", vm.fetch(english_id).?);
    try std.testing.expectEqualStrings("hallo, welt", vm.fetch(german_id).?);
    try std.testing.expectEqual(vm.fetch(3), null);
}

test "shell hello world" {
    var emitter = try lang.Emitter.init(std.testing.allocator);
    defer emitter.deinit();

    const out = try emitter.add_export("out");

    try emitter.clear();
    try emitter.append_const("echo ");
    try emitter.append_const("hello");
    try emitter.append_const(" ");
    try emitter.append_const("world");
    try emitter.push_scratch();
    try emitter.clear();
    try emitter.exec_cmd();
    try emitter.set_export(out);
    try emitter.exit();

    var vm = try lang.Vm.init(std.testing.allocator);
    defer vm.deinit();

    var prog = emitter.emit();

    try vm.run(&prog);

    try std.testing.expectEqualStrings("hello world\n", vm.fetch(out).?);
    try std.testing.expectEqual(vm.fetch(1), null);
}
