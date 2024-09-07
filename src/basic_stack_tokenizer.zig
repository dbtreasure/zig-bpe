const std = @import("std");

pub const TrainError = error{
    InvalidVocabSize,
    InvalidUtf8,
    OutOfMemory,
};

const Merge = struct {
    pair: CharPair,
    new_token: u16,
};

const Merges = struct {
    merges: std.AutoHashMap(CharPair, u16),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) @This() {
        return .{
            .merges = std.AutoHashMap(CharPair, u16).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Merges) void {
        self.merges.deinit();
    }

    pub fn put(self: *Merges, pair: CharPair, new_token: u16) !void {
        try self.merges.put(pair, new_token);
    }
};

const CharPair = struct {
    first: u16,
    second: u16,
};

const PairCount = struct {
    pair: u32,
    count: usize,
};

const CharPairFrequencies = struct {
    frequencies: std.AutoHashMap(u32, usize),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) @This() {
        return .{
            .frequencies = std.AutoHashMap(u32, usize).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CharPairFrequencies) void {
        self.frequencies.deinit();
    }
};

const vocabStart: u16 = 256;

pub const BasicTokenizer = struct {
    tokens: std.ArrayList(u16),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !@This() {
        return .{
            .tokens = std.ArrayList(u16).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BasicTokenizer) void {
        self.tokens.deinit();
    }

    pub fn train(self: *BasicTokenizer, text: []const u8, vocabSize: u16) TrainError!void {
        if (vocabSize < 256) {
            return TrainError.InvalidVocabSize;
        }
        // print text length
        std.debug.print("text length: {}\n", .{text.len});
        const tokens = try generateInitialTokens(self.allocator, text);
        std.debug.print("tokens length: {}\n", .{tokens.items.len});
        try self.expandVocabulary(self.allocator, tokens, vocabSize);
    }

    fn generateInitialTokens(allocator: std.mem.Allocator, text: []const u8) TrainError!std.ArrayList(u16) {
        var tokens = std.ArrayList(u16).init(allocator);
        errdefer tokens.deinit();

        for (text) |byte| {
            try tokens.append(@as(u16, byte));
        }

        return tokens;
    }

    fn expandVocabulary(self: *BasicTokenizer, allocator: std.mem.Allocator, tokens: std.ArrayList(u16), vocabSize: u16) TrainError!void {
        var currentTokens = try std.ArrayList(u16).initCapacity(allocator, tokens.items.len);
        try currentTokens.appendSlice(tokens.items);

        var merges = Merges.init(allocator);
        defer merges.deinit();

        var currentIndex: u16 = vocabStart;
        while (currentIndex < vocabSize) : (currentIndex += 1) {
            const stats = try countCodePointPairs(&currentTokens, allocator);
            const sorted_pairs = try sortCodePointPairs(stats, allocator);
            // top pair is the first element
            const topPair = sorted_pairs[0];
            const charPair = CharPair{
                .first = @as(u16, @truncate(topPair.pair >> 16)),
                .second = @as(u16, @truncate(topPair.pair & 0xFFFF)),
            };
            try merges.put(charPair, currentIndex);

            // Add this print statement
            std.debug.print("merge {d}/{d}: ({d},{d}) -> {d} had {d} occurrences\n", .{
                currentIndex - vocabStart + 1,
                vocabSize - vocabStart,
                charPair.first,
                charPair.second,
                currentIndex,
                topPair.count,
            });

            try replaceTopPairWithIndex(&currentTokens, charPair, currentIndex);
        }

        try self.tokens.appendSlice(currentTokens.items);
    }

    fn replaceTopPairWithIndex(tokens: *std.ArrayList(u16), pair: CharPair, newToken: u16) TrainError!void {
        var i: usize = 0;
        var j: usize = 0;
        while (i < tokens.items.len - 1) {
            if (tokens.items[i] == pair.first and tokens.items[i + 1] == pair.second) {
                tokens.items[j] = newToken;
                i += 2;
            } else {
                tokens.items[j] = tokens.items[i];
                i += 1;
            }
            j += 1;
        }
        if (i < tokens.items.len) {
            tokens.items[j] = tokens.items[i];
            j += 1;
        }
        try tokens.resize(j);
    }
};

fn countCodePointPairs(tokens: *std.ArrayList(u16), allocator: std.mem.Allocator) !std.AutoHashMap(u32, usize) {
    var pairCounts = std.AutoHashMap(u32, usize).init(allocator);
    errdefer pairCounts.deinit();

    if (tokens.items.len < 2) {
        return pairCounts;
    }

    var i: usize = 0;
    while (i < tokens.items.len - 1) : (i += 1) {
        const pair = (@as(u32, tokens.items[i]) << 16) | tokens.items[i + 1];
        const gop = try pairCounts.getOrPut(pair);
        if (!gop.found_existing) {
            gop.value_ptr.* = 1;
        } else {
            gop.value_ptr.* += 1;
        }
    }

    return pairCounts;
}

fn sortCodePointPairs(pairCounts: std.AutoHashMap(u32, usize), allocator: std.mem.Allocator) ![]PairCount {
    var sortedPairs = try allocator.alloc(PairCount, pairCounts.count());
    errdefer allocator.free(sortedPairs);

    var i: usize = 0;
    var it = pairCounts.iterator();
    while (it.next()) |entry| : (i += 1) {
        sortedPairs[i] = .{
            .pair = entry.key_ptr.*,
            .count = entry.value_ptr.*,
        };
    }

    std.mem.sort(PairCount, sortedPairs, {}, struct {
        pub fn compare(_: void, a: PairCount, b: PairCount) bool {
            return a.count > b.count;
        }
    }.compare);

    return sortedPairs;
}
