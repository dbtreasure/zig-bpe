const std = @import("std");
const main = @import("main.zig");
const constants = @import("constants.zig");
const expect = std.testing.expect;
const expectEqualSlices = std.testing.expectEqualSlices;

test "replaceTopPairWithIndex" {
    // Initialize the allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create the initial tokens
    var tokens = std.ArrayList(u16).init(allocator);
    defer tokens.deinit();
    try tokens.appendSlice(&[_]u16{ 5, 6, 6, 7, 9, 1 });

    // Define the top pair and new index
    const top_pair = constants.CharPair{ .first = 6, .second = 7 };
    const new_index: u16 = 99;

    // Call the function we're testing
    const new_tokens = try main.replaceTopPairWithIndex(tokens.items, top_pair, new_index);
    defer new_tokens.deinit();

    // Define the expected result
    const expected = [_]u16{ 5, 6, 99, 9, 1 };

    // Check if the result matches the expected output
    try expectEqualSlices(u16, &expected, new_tokens.items);

    // Print the result (optional, for visual confirmation)
    std.debug.print("Result: {any}\n", .{new_tokens.items});
}