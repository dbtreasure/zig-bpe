const std = @import("std");
const constants = @import("constants.zig");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    const text = try readFile(constants.INPUT_FILE_PATH);
    defer std.heap.page_allocator.free(text);
    
    const tokens = try getTokensFromString(text);
    
    var stats = try getStats(tokens.items);
    defer stats.deinit();

    const sorted_stats = try sortStats(stats);
    defer sorted_stats.deinit();

    const top_pair = try getTopPair(stats);
    try stdout.print("Top pair: ({}, {})\n", .{ top_pair.first, top_pair.second });
    
    try stdout.print("\n", .{});

    const new_tokens = try replaceTopPairWithIndex(tokens.items, top_pair, constants.DEFAULT_INDEX);

    try stdout.print("Length of tokens: {}\n", .{tokens.items.len});
    try stdout.print("New tokens: {}\n", .{new_tokens.items.len});
}

fn replaceTopPairWithIndex(tokens: []const u16, top_pair: constants.CharPair, index: u16) !std.ArrayList(u16) {
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

fn getTokensFromString(text: []const u8) !std.ArrayList(u16) {
    var integers = std.ArrayList(u16).init(std.heap.page_allocator);
    for (text) |char| {
        try integers.append(@as(u16, char));
    }
    return integers;
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

fn readFile(path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try std.heap.page_allocator.alloc(u8, file_size);
    _ = try file.readAll(buffer);

    return buffer;
}