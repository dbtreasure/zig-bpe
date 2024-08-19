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

test "expandVocabulary" {
    // Initialize the allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Read the input file
    const text = try main.readFile(constants.INPUT_FILE_PATH);
    defer allocator.free(text);

    // Get initial tokens
    const initial_tokens = try main.getTokensFromString(text);
    defer initial_tokens.deinit();

    // Define the target vocabulary size
    const new_vocab_size: u16 = 276;

    // Expand the vocabulary
    const expanded_result = try main.expandVocabulary(initial_tokens.items, new_vocab_size);
    defer expanded_result.tokens.deinit();
    defer expanded_result.merges.deinit();

    // Print results for debugging
    std.debug.print("Length of original tokens: {}\n", .{initial_tokens.items.len});
    std.debug.print("Length of expanded tokens: {}\n", .{expanded_result.tokens.items.len});
    std.debug.print("Number of merges: {}\n", .{expanded_result.merges.items.len});
    std.debug.print("New vocabulary size: {}\n", .{new_vocab_size});

    // Check if the expanded tokens are fewer than the initial tokens
    try expect(expanded_result.tokens.items.len < initial_tokens.items.len);

    // Check if the number of merges is correct
    try expect(expanded_result.merges.items.len == new_vocab_size - constants.DEFAULT_INDEX);

    // Check if the new vocabulary size is reached
    try expect(expanded_result.merges.items.len + constants.DEFAULT_INDEX == new_vocab_size);
}

test "tokenization round trip" {
    // Read the input file
    const original_text = try main.readFile(constants.INPUT_FILE_PATH);
    defer std.heap.page_allocator.free(original_text);

    // Tokenize
    const tokens = try main.getTokensFromString(original_text);
    defer tokens.deinit();

    // Expand vocabulary
    const new_vocab_size: u16 = 276;
    const expanded_result = try main.expandVocabulary(tokens.items, new_vocab_size);
    defer expanded_result.tokens.deinit();
    defer expanded_result.merges.deinit();

    // Detokenize
    var reconstructed_text = try main.getStringFromTokensAndMerges(expanded_result.tokens, expanded_result.merges);
    defer reconstructed_text.deinit();

    // Compare
    for (0..original_text.len) |i| {
        try std.testing.expectEqual(original_text[i], reconstructed_text.items[i]);
    }

    // Print success message
    std.debug.print("Tokenization round-trip successful\n", .{});
}