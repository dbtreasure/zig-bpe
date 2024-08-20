const std = @import("std");
const main = @import("main.zig");
const constants = @import("constants.zig");
const expect = std.testing.expect;
const expectEqualSlices = std.testing.expectEqualSlices;

// Update the constant at the top of the file
const SIMPLE_INPUT_FILE_PATH = "simple_input.txt";

test "replaceTopPairWithIndex" {
    // Initialize the allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create the initial tokens
    var tokens = std.ArrayList(u21).init(allocator);
    defer tokens.deinit();
    try tokens.appendSlice(&[_]u21{ 5, 6, 6, 7, 9, 1 });

    // Define the top pair and new index
    const top_pair = constants.CharPair{ .first = 6, .second = 7 };
    const new_index: u21 = 99;

    // Call the function we're testing
    const new_tokens = try main.replaceTopPairWithIndex(tokens.items, top_pair, new_index);
    defer new_tokens.deinit();

    // Define the expected result
    const expected = [_]u21{ 5, 6, 99, 9, 1 };

    // Check if the result matches the expected output
    try expectEqualSlices(u21, &expected, new_tokens.items);

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
    const new_vocab_size: u21 = 276;

    // Expand the vocabulary
    const expanded_result = try main.expandVocabulary(initial_tokens.items, new_vocab_size);
    defer expanded_result.tokens.deinit();
    defer expanded_result.merges.deinit();

    // Print results for debugging
    std.debug.print("Original tokens length: {}\n", .{initial_tokens.items.len});
    std.debug.print("Expanded tokens length: {}\n", .{expanded_result.tokens.items.len});
    std.debug.print("Number of merges: {}\n", .{expanded_result.merges.items.len});

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
    const new_vocab_size: u21 = 276;
    const expanded_result = try main.expandVocabulary(tokens.items, new_vocab_size);
    defer expanded_result.tokens.deinit();
    defer expanded_result.merges.deinit();

    // Detokenize
    var reconstructed_text = try main.getStringFromTokensAndMerges(expanded_result.tokens, expanded_result.merges);
    defer reconstructed_text.deinit();

    // Compare
    const min_len = @min(original_text.len, reconstructed_text.items.len);
    for (0..min_len) |i| {
        if (original_text[i] != reconstructed_text.items[i]) {
            std.debug.print("Mismatch at index {}: original '{}' ({}), reconstructed '{}' ({})\n", .{
                i,
                original_text[i],
                original_text[i],
                reconstructed_text.items[i],
                reconstructed_text.items[i],
            });

            const orig_start = if (i >= 5) i - 5 else 0;
            const orig_end = @min(i + 6, original_text.len);
            const recon_start = if (i >= 5) i - 5 else 0;
            const recon_end = @min(i + 6, reconstructed_text.items.len);

            std.debug.print("Context: original: '{s}'\n", .{original_text[orig_start..orig_end]});
            std.debug.print("Context: reconstructed: '{s}'\n", .{reconstructed_text.items[recon_start..recon_end]});

            // Print token information
            const start_token = if (i >= 5) i - 5 else 0;
            const end_token = @min(i + 6, expanded_result.tokens.items.len);
            if (start_token < end_token) {
                std.debug.print("Tokens around mismatch: {any}\n", .{expanded_result.tokens.items[start_token..end_token]});
            } else {
                std.debug.print("Unable to print tokens around mismatch: index out of bounds\n", .{});
            }

            return error.TokenizationMismatch;
        }
    }

    // Check if lengths are different
    if (original_text.len != reconstructed_text.items.len) {
        std.debug.print("Length mismatch: original {} vs reconstructed {}\n", .{ original_text.len, reconstructed_text.items.len });
        return error.TokenizationLengthMismatch;
    }

    // If we've made it this far, the test has passed
    std.debug.print("Tokenization round-trip successful\n", .{});
}

test "simple tokenization round trip" {
    // Read the simple input file
    const original_text = try main.readFile(SIMPLE_INPUT_FILE_PATH);
    defer std.heap.page_allocator.free(original_text);

    // Tokenize
    const tokens = try main.getTokensFromString(original_text);
    defer tokens.deinit();

    // Expand vocabulary (using a smaller size for this simple test)
    const new_vocab_size: u21 = 150;
    const expanded_result = try main.expandVocabulary(tokens.items, new_vocab_size);
    defer expanded_result.tokens.deinit();
    defer expanded_result.merges.deinit();

    // Detokenize
    var reconstructed_text = try main.getStringFromTokensAndMerges(expanded_result.tokens, expanded_result.merges);
    defer reconstructed_text.deinit();

    // Print debug information
    std.debug.print("Original text: '{s}'\n", .{original_text});
    std.debug.print("Reconstructed text: '{s}'\n", .{reconstructed_text.items});

    // Compare
    try std.testing.expectEqualStrings(original_text, reconstructed_text.items);

    // If we've made it this far, the test has passed
    std.debug.print("Simple tokenization round-trip successful\n", .{});
}

test "createVocab" {
    // Initialize the allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create some sample merges
    var merges = std.ArrayList(constants.Merge).init(allocator);
    defer merges.deinit();
    try merges.append(.{ .pair = .{ .first = 'H', .second = 'e' }, .new_token = 256 });
    try merges.append(.{ .pair = .{ .first = 'l', .second = 'l' }, .new_token = 257 });
    try merges.append(.{ .pair = .{ .first = 256, .second = 'l' }, .new_token = 258 });

    // Create the vocabulary
    var vocab = try main.createVocab(merges.items, allocator);
    defer main.freeVocab(&vocab);

    // Check the size of the vocabulary
    try std.testing.expectEqual(@as(usize, 259), vocab.count());

    // Check some specific entries
    try std.testing.expectEqualStrings("H", vocab.get('H').?);
    try std.testing.expectEqualStrings("e", vocab.get('e').?);
    try std.testing.expectEqualStrings("l", vocab.get('l').?);
    try std.testing.expectEqualStrings("He", vocab.get(256).?);
    try std.testing.expectEqualStrings("ll", vocab.get(257).?);
    try std.testing.expectEqualStrings("Hel", vocab.get(258).?);

    // Check a non-existent entry
    try std.testing.expect(vocab.get(259) == null);

    std.debug.print("createVocab test passed successfully\n", .{});
}

test "decode" {
    // Initialize the allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create a sample vocabulary
    var vocab = main.Vocab.init(allocator);
    defer main.freeVocab(&vocab);

    // Add some entries to the vocabulary
    try vocab.put(0, try allocator.dupe(u8, "H"));
    try vocab.put(1, try allocator.dupe(u8, "e"));
    try vocab.put(2, try allocator.dupe(u8, "l"));
    try vocab.put(3, try allocator.dupe(u8, "o"));
    try vocab.put(256, try allocator.dupe(u8, "He"));
    try vocab.put(257, try allocator.dupe(u8, "ll"));
    try vocab.put(258, try allocator.dupe(u8, "o!"));

    // Create a sample token sequence
    const tokens = [_]u21{ 256, 257, 258 };

    // Decode the tokens
    const decoded = try main.decode(&tokens, vocab, allocator);
    defer allocator.free(decoded);

    // Check the decoded result
    try std.testing.expectEqualStrings("Hello!", decoded);

    // Test with an invalid token
    const invalid_tokens = [_]u21{ 256, 999, 258 };
    try std.testing.expectError(error.InvalidToken, main.decode(&invalid_tokens, vocab, allocator));

    std.debug.print("decode test passed successfully\n", .{});
}

test "encode and decode round trip" {
    // Initialize the allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

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

    // Create vocabulary
    var vocab = try main.createVocab(expanded_result.merges.items, allocator);
    defer main.freeVocab(&vocab);

    // Decode the expanded tokens
    const decoded = try main.decode(expanded_result.tokens.items, vocab, allocator);
    defer allocator.free(decoded);

    // Compare original and decoded text
    try std.testing.expectEqualStrings(original_text, decoded);

    // Print debug information
    std.debug.print("Original text length: {}\n", .{original_text.len});
    std.debug.print("Decoded text length: {}\n", .{decoded.len});
    std.debug.print("Vocabulary size: {}\n", .{vocab.count()});
    std.debug.print("Number of tokens: {}\n", .{expanded_result.tokens.items.len});

    // If we've made it this far, the test has passed
    std.debug.print("Encode and decode round-trip successful\n", .{});
}

test "encode and decode" {
    // Initialize the allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Create a sample vocabulary
    var vocab = main.Vocab.init(allocator);
    defer main.freeVocab(&vocab);

    // Add some entries to the vocabulary
    try vocab.put(0, try allocator.dupe(u8, "H"));
    try vocab.put(1, try allocator.dupe(u8, "e"));
    try vocab.put(2, try allocator.dupe(u8, "l"));
    try vocab.put(3, try allocator.dupe(u8, "o"));
    try vocab.put(4, try allocator.dupe(u8, " "));
    try vocab.put(5, try allocator.dupe(u8, "w"));
    try vocab.put(6, try allocator.dupe(u8, "r"));
    try vocab.put(7, try allocator.dupe(u8, "d"));
    try vocab.put(8, try allocator.dupe(u8, "!"));
    try vocab.put(256, try allocator.dupe(u8, "He"));
    try vocab.put(257, try allocator.dupe(u8, "ll"));
    try vocab.put(258, try allocator.dupe(u8, "o "));
    try vocab.put(259, try allocator.dupe(u8, "wor"));
    try vocab.put(260, try allocator.dupe(u8, "ld"));

    // Create a sample text
    const original_text = "Hello world!";

    // Define the expected encoded result
    const expected_encoded = [_]u21{ 256, 257, 258, 259, 260, 8 };

    // Encode the text
    const encoded = try main.encode(original_text, vocab, allocator);
    defer allocator.free(encoded);

    // Print debug information
    std.debug.print("Original text: '{s}'\n", .{original_text});
    std.debug.print("Encoded result: {any}\n", .{encoded});
    std.debug.print("Expected encoded: {any}\n", .{expected_encoded});

    // Check the encoded result
    try std.testing.expectEqualSlices(u21, &expected_encoded, encoded);

    // Decode the encoded result
    const decoded = try main.decode(encoded, vocab, allocator);
    defer allocator.free(decoded);

    // Check if the decoded text matches the original
    try std.testing.expectEqualStrings(original_text, decoded);

    std.debug.print("encode and decode test passed successfully\n", .{});
}

test "simple encode and decode round trip" {
    // Initialize the allocator
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Read the simple input file
    const original_text = try main.readFile(SIMPLE_INPUT_FILE_PATH);
    defer std.heap.page_allocator.free(original_text);

    // Tokenize
    const tokens = try main.getTokensFromString(original_text);
    defer tokens.deinit();

    // Expand vocabulary (using a smaller size for this simple test)
    const new_vocab_size: u16 = 300;
    const expanded_result = try main.expandVocabulary(tokens.items, new_vocab_size);
    defer expanded_result.tokens.deinit();
    defer expanded_result.merges.deinit();

    // Create vocabulary
    var vocab = try main.createVocab(expanded_result.merges.items, allocator);
    defer main.freeVocab(&vocab);

    // Encode the original text
    const encoded = try main.encode(original_text, vocab, allocator);
    defer allocator.free(encoded);

    // Decode the encoded result
    const decoded = try main.decode(encoded, vocab, allocator);
    defer allocator.free(decoded);

    // Print debug information
    std.debug.print("Original text: '{s}'\n", .{original_text});
    std.debug.print("Encoded tokens: {any}\n", .{encoded});
    std.debug.print("Decoded text: '{s}'\n", .{decoded});
    std.debug.print("Vocabulary size: {}\n", .{vocab.count()});
    std.debug.print("Number of tokens: {}\n", .{encoded.len});
    std.debug.print("Compression ratio: {d:.2}\n", .{@as(f32, @floatFromInt(original_text.len)) / @as(f32, @floatFromInt(encoded.len))});

    // Check if the decoded text matches the original
    try std.testing.expectEqualStrings(original_text, decoded);

    std.debug.print("Simple encode and decode round-trip successful\n", .{});
}
