const std = @import("std");

const CharPair = struct {
    first: u16,
    second: u16,
};

const StatEntry = struct {
    key: CharPair,
    value: usize,
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    // Read the text from the file
    const text = try readFile("input.txt");
    defer std.heap.page_allocator.free(text);
    
    const tokens = try getTokensFromString(text);
    
    var stats = try getStats(tokens.items);
    defer stats.deinit();

    const sorted_stats = try sortStats(stats);
    defer sorted_stats.deinit();

    const top_pair = try getTopPair(stats);
    try stdout.print("Top pair: ({}, {})\n", .{ top_pair.first, top_pair.second });
    
    try stdout.print("\n", .{});

    const new_tokens = try replaceTopPairWithIndex(tokens.items, top_pair, 256);

    try stdout.print("Length of tokens: {}\n", .{tokens.items.len});
    try stdout.print("New tokens: {}\n", .{new_tokens.items.len});
}

fn replaceTopPairWithIndex(tokens: []const u16, top_pair: CharPair, index: u16) !std.ArrayList(u16) {
    var new_tokens = std.ArrayList(u16).init(std.heap.page_allocator);
    var i: usize = 0;
    while (i < tokens.len) : (i += 1) {
        if (tokens.len - i >= 2 and std.mem.eql(u16, tokens[i..i+2], &[_]u16{ top_pair.first, top_pair.second })) {
            try new_tokens.append(index);
            i += 1; // Skip the next token as we've consumed the pair
        } else {
            try new_tokens.append(tokens[i]);
        }
    }
    return new_tokens;
}

fn getTokensFromString(text: []const u8) !std.ArrayList(u16) {
    var integers = std.ArrayList(u16).init(std.heap.page_allocator);
    for (text) |char| {
        try integers.append(@as(u16, char));
    }
    return integers;
}

fn getStats(ids: []const u16) !std.AutoHashMap(CharPair, usize) {
    var counts = std.AutoHashMap(CharPair, usize).init(std.heap.page_allocator);

    for (0..ids.len - 1) |i| {
        const pair = CharPair{ .first = ids[i], .second = ids[i + 1] };
        const entry = try counts.getOrPut(pair);
        if (entry.found_existing) {
            entry.value_ptr.* += 1;
        } else {
            entry.value_ptr.* = 1;
        }
    }

    return counts;
}

fn sortStats(stats: std.AutoHashMap(CharPair, usize)) !std.ArrayList(StatEntry) {
    var sorted = std.ArrayList(StatEntry).init(std.heap.page_allocator);
    var it = stats.iterator();

    while (it.next()) |entry| {
        try sorted.append(.{ .key = entry.key_ptr.*, .value = entry.value_ptr.* });
    }

    std.mem.sort(StatEntry, sorted.items, {}, compByValueDesc);
    return sorted;
}

fn compByValueDesc(_: void, a: StatEntry, b: StatEntry) bool {
    return a.value > b.value;
}

fn getTopPair(stats: std.AutoHashMap(CharPair, usize)) !CharPair {
    var it = stats.iterator();
    var top_pair: CharPair = undefined;
    var top_value: usize = 0;
    while (it.next()) |entry| {
        if (entry.value_ptr.* > top_value) {
            top_value = entry.value_ptr.*;
            top_pair = entry.key_ptr.*;
        }
    }
    return top_pair;
}

// New function to read the file
fn readFile(path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try std.heap.page_allocator.alloc(u8, file_size);
    _ = try file.readAll(buffer);

    return buffer;
}