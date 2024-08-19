const std = @import("std");
const constants = @import("constants.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    const text = try readFile(constants.INPUT_FILE_PATH);
    defer std.heap.page_allocator.free(text);
    
    const tokens = try getTokensFromString(text);
    defer tokens.deinit();
    
    var stats = try getStats(tokens.items);
    defer stats.deinit();

    const sorted_stats = try sortStats(stats);
    defer sorted_stats.deinit();

    const top_pair = try getTopPair(stats);

    const new_tokens = try replaceTopPairWithIndex(tokens.items, top_pair, constants.DEFAULT_INDEX);
    defer new_tokens.deinit();

    const new_vocab_size: u16 = 276;
    const expanded_result = try expandVocabulary(tokens.items, new_vocab_size);
    defer expanded_result.tokens.deinit();
    defer expanded_result.merges.deinit();

    var expanded_string = try getStringFromTokensAndMerges(expanded_result.tokens, expanded_result.merges);
    defer expanded_string.deinit();

    const original_length = tokens.items.len;
    const compressed_length = expanded_result.tokens.items.len;
    const compression_ratio = @as(f32, @floatFromInt(original_length)) / @as(f32, @floatFromInt(compressed_length));

    try stdout.print("Length of original tokens: {}\n", .{original_length});
    try stdout.print("Length of expanded tokens: {}\n", .{compressed_length});
    try stdout.print("New vocabulary size: {}\n", .{new_vocab_size});
    try stdout.print("Compression ratio: {d:.2}X\n", .{compression_ratio});
}

pub fn getTokensFromString(text: []const u8) !std.ArrayList(u16) {
    var integers = std.ArrayList(u16).init(std.heap.page_allocator);
    for (text) |char| {
        try integers.append(@as(u16, char));
    }
    return integers;
}

pub fn getStringFromTokens(tokens: []const u16) !std.ArrayList(u8) {
    var string = std.ArrayList(u8).init(std.heap.page_allocator);
    errdefer string.deinit();

    for (tokens) |token| {
        try string.append(@truncate(token));
    }
    return string;
}

pub fn getStringFromTokensAndMerges(tokens: std.ArrayList(u16), merges: std.ArrayList(constants.Merge)) !std.ArrayList(u8) {
    var current_tokens = try tokens.clone();
    defer current_tokens.deinit();

    // Iterate through merges in reverse order
    var i: usize = merges.items.len;
    while (i > 0) {
        i -= 1;
        const merge = merges.items[i];
        
        var new_tokens = std.ArrayList(u16).init(std.heap.page_allocator);
        errdefer new_tokens.deinit();
        
        for (current_tokens.items) |token| {
            if (token == merge.new_token) {
                try new_tokens.append(merge.pair.first);
                try new_tokens.append(merge.pair.second);
            } else {
                try new_tokens.append(token);
            }
        }

        // Replace current_tokens with new_tokens
        current_tokens.deinit();
        current_tokens = new_tokens;
    }

    // Convert the final tokens to a string
    return try getStringFromTokens(current_tokens.items);
}

fn getStats(ids: []const u16) !std.AutoHashMap(constants.CharPair, usize) {
    var counts = std.AutoHashMap(constants.CharPair, usize).init(std.heap.page_allocator);

    for (0..ids.len - 1) |i| {
        const pair = constants.CharPair{ .first = ids[i], .second = ids[i + 1] };
        const entry = try counts.getOrPut(pair);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    return counts;
}

fn sortStats(stats: std.AutoHashMap(constants.CharPair, usize)) !std.ArrayList(constants.StatEntry) {
    var sorted = std.ArrayList(constants.StatEntry).init(std.heap.page_allocator);
    var it = stats.iterator();

    while (it.next()) |entry| {
        try sorted.append(.{ .key = entry.key_ptr.*, .value = entry.value_ptr.* });
    }

    std.mem.sort(constants.StatEntry, sorted.items, {}, compByValueDesc);
    return sorted;
}

fn compByValueDesc(_: void, a: constants.StatEntry, b: constants.StatEntry) bool {
    return a.value > b.value;
}

fn getTopPair(stats: std.AutoHashMap(constants.CharPair, usize)) !constants.CharPair {
    var it = stats.iterator();
    var top_pair: constants.CharPair = undefined;
    var top_value: usize = 0;
    while (it.next()) |entry| {
        if (entry.value_ptr.* > top_value) {
            top_value = entry.value_ptr.*;
            top_pair = entry.key_ptr.*;
        }
    }
    return top_pair;
}

pub fn replaceTopPairWithIndex(tokens: []const u16, top_pair: constants.CharPair, index: u16) !std.ArrayList(u16) {
    var new_tokens = std.ArrayList(u16).init(std.heap.page_allocator);
    var i: usize = 0;
    while (i < tokens.len) : (i += 1) {
        if (isMatchingPairAtIndex(tokens, i, top_pair)) {
            try new_tokens.append(index);
            i += 1; // Skip the next token as we've consumed the pair
        } else {
            try new_tokens.append(tokens[i]);
        }
    }
    return new_tokens;
}

fn isMatchingPairAtIndex(tokens: []const u16, index: usize, pair: constants.CharPair) bool {
    if (tokens.len - index < 2) return false;
    
    const tokenPair = constants.TokenPair{ .tokens = tokens, .index = index };
    return std.mem.eql(u16, tokenPair.slice(), &pair.asSlice());
}

pub fn readFile(path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try std.heap.page_allocator.alloc(u8, file_size);
    _ = try file.readAll(buffer);

    return buffer;
}

pub fn expandVocabulary(initial_tokens: []const u16, target_vocab_size: u16) !struct { tokens: std.ArrayList(u16), merges: std.ArrayList(constants.Merge) } {
    var current_tokens = try std.ArrayList(u16).initCapacity(std.heap.page_allocator, initial_tokens.len);
    try current_tokens.appendSlice(initial_tokens);

    var merges = std.ArrayList(constants.Merge).init(std.heap.page_allocator);

    var current_index: u16 = constants.DEFAULT_INDEX;

    while (current_index < target_vocab_size) : (current_index += 1) {
        var stats = try getStats(current_tokens.items);
        defer stats.deinit();

        const top_pair = try getTopPair(stats);
        
        try merges.append(.{ .pair = top_pair, .new_token = current_index });
        
        const new_tokens = try replaceTopPairWithIndex(current_tokens.items, top_pair, current_index);

        current_tokens.deinit();
        current_tokens = new_tokens;
    }

    return .{ .tokens = current_tokens, .merges = merges };
}