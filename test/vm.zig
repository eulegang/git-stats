const std = @import("std");
const lang = @import("lang");

test "simple execution example" {
    var emitter = try lang.Emitter.init(std.testing.allocator);
    defer emitter.deinit();

    const english_id = try emitter.add_export("english");
    const german_id = try emitter.add_export("german");

    try emitter.clear();
    try emitter.append("hello");
    try emitter.append(", ");
    try emitter.append("world");
    try emitter.push_scratch();
    try emitter.set_export(english_id);
    try emitter.clear();
    try emitter.append("hallo, welt");
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
