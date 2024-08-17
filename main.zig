const std = @import("std");

const CharPair = struct {
    first: u8,
    second: u8,
};

const StatEntry = struct {
    key: CharPair,
    value: usize,
};

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const text =
        \\Ｕｎｉｃｏｄｅ! 🅤🅝🅘🅒🅞🅓🅔‽ 🇺‌🇳‌🇮‌🇨‌🇴‌🇩‌🇪! 😄 The very name strikes fear and awe into the hearts of programmers worldwide. We all know we ought to "support Unicode" in our software (whatever that means—like using wchar_t for all the strings, right?). But Unicode can be abstruse, and diving into the thousand-page Unicode Standard plus its dozens of supplementary annexes, reports, and notes can be more than a little intimidating. I don't blame programmers for still finding the whole thing mysterious, even 30 years after Unicode's inception.
    ;
    const integers = try getIntegersFromString(text);
    
    var stats = try getStats(integers.items);
    defer stats.deinit();

    const sorted_stats = try sortStats(stats);
    defer sorted_stats.deinit();

    const top_pair = try getTopPair(stats);
    try stdout.print("Top pair: ({}, {})\n", .{ top_pair.first, top_pair.second });
}

fn getIntegersFromString(text: []const u8) !std.ArrayList(u8) {
    var integers = std.ArrayList(u8).init(std.heap.page_allocator);
    for (text) |char| {
        try integers.append(char);
    }
    return integers;
}

fn getStats(ids: []const u8) !std.AutoHashMap(CharPair, usize) {
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