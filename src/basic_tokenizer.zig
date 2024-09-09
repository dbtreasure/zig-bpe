const std = @import("std");

const TimeStats = @import("utils/time_statistics.zig").TimeStats;
const printTimeStats = @import("utils/time_statistics.zig").printTimeStats;

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

    pub fn put(self: *Merges, pair: PairCount, new_token: u16) !void {
        const charPair = CharPair{
            .first = @as(u16, @truncate(pair.pair >> 16)),
            .second = @as(u16, @truncate(pair.pair & 0xFFFF)),
        };
        try self.merges.put(charPair, new_token);
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
    allocator: std.mem.Allocator,
    tokens: std.ArrayList(u16),
    timeStats: *TimeStats,

    pub fn init(allocator: std.mem.Allocator) !@This() {
        const timeStats = try TimeStats.init(allocator);
        return .{
            .allocator = allocator,
            .tokens = std.ArrayList(u16).init(allocator),
            .timeStats = timeStats,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.tokens.deinit();
        self.timeStats.deinit();
    }

    pub fn train(self: *@This(), text: []const u8, vocabSize: u16) TrainError!void {
        const start = std.time.milliTimestamp();
        defer {
            const end = std.time.milliTimestamp();
            const total_time = end - start;
            printTimeStats(self.timeStats, total_time);
        }

        if (vocabSize < 256) {
            return TrainError.InvalidVocabSize;
        }
        const tokens = try self.generateInitialTokens(text);
        defer tokens.deinit();
        try self.expandVocabulary(tokens, vocabSize);
    }

    fn generateInitialTokens(self: *BasicTokenizer, text: []const u8) TrainError!std.ArrayList(u16) {
        const start = std.time.milliTimestamp();
        defer {
            const end = std.time.milliTimestamp();
            std.debug.print("generateInitialTokens runtime: {d:.3} seconds\n", .{@as(f64, @floatFromInt(end - start)) / 1000.0});
        }

        var tokens = std.ArrayList(u16).init(self.allocator);
        errdefer tokens.deinit();

        for (text) |byte| {
            try tokens.append(@as(u16, byte));
        }

        return tokens;
    }

    fn expandVocabulary(self: *BasicTokenizer, tokens: std.ArrayList(u16), vocabSize: u16) TrainError!void {
        var currentTokens = try std.ArrayList(u16).initCapacity(self.allocator, tokens.items.len);
        try currentTokens.appendSlice(tokens.items);
        defer currentTokens.deinit();

        var merges = Merges.init(self.allocator);
        defer merges.deinit();

        var currentIndex: u16 = vocabStart;
        while (currentIndex < vocabSize) : (currentIndex += 1) {
            var codePointPairs = try self.generateCodePointPairs(&currentTokens, self.timeStats);
            defer codePointPairs.deinit();

            var codePointPairCounts = try self.countCodePointPairs(&codePointPairs, self.timeStats);
            defer codePointPairCounts.deinit();

            const sortedCodePointPairs = try self.sortCodePointPairs(codePointPairCounts, self.timeStats);
            defer self.allocator.free(sortedCodePointPairs);

            const topCodePointPair = sortedCodePointPairs[0];

            self.printMergeInfo(currentIndex, vocabSize, topCodePointPair);

            try merges.put(topCodePointPair, currentIndex);

            try replaceTopPairWithNewToken(&currentTokens, topCodePointPair, currentIndex, self.timeStats);
        }

        try self.tokens.appendSlice(currentTokens.items);
    }

    fn replaceTopPairWithNewToken(tokens: *std.ArrayList(u16), pair: PairCount, newToken: u16, stats: *TimeStats) TrainError!void {
        const charPair = CharPair{
            .first = @as(u16, @truncate(pair.pair >> 16)),
            .second = @as(u16, @truncate(pair.pair & 0xFFFF)),
        };
        const start = std.time.milliTimestamp();
        defer {
            const end = std.time.milliTimestamp();
            stats.replace_pair_time += end - start;
            stats.replace_pair_calls += 1;
        }

        var i: usize = 0;
        var j: usize = 0;
        while (i < tokens.items.len - 1) {
            if (tokens.items[i] == charPair.first and tokens.items[i + 1] == charPair.second) {
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

    fn generateCodePointPairs(self: *BasicTokenizer, tokens: *std.ArrayList(u16), stats: *TimeStats) !std.ArrayList(u32) {
        const start = std.time.milliTimestamp();
        defer {
            const end = std.time.milliTimestamp();
            stats.generate_pairs_time += end - start;
            stats.generate_pairs_calls += 1;
        }

        var pairs = std.ArrayList(u32).init(self.allocator);
        errdefer pairs.deinit();

        var i: usize = 0;
        while (i < tokens.items.len - 1) : (i += 1) {
            const pair = (@as(u32, tokens.items[i]) << 16) | tokens.items[i + 1];
            try pairs.append(pair);
        }

        return pairs;
    }

    fn countCodePointPairs(self: *BasicTokenizer, pairs: *std.ArrayList(u32), stats: *TimeStats) !std.AutoHashMap(u32, usize) {
        const start = std.time.milliTimestamp();
        defer {
            const end = std.time.milliTimestamp();
            stats.just_count_pairs_time += end - start;
            stats.just_count_pairs_calls += 1;
        }

        var pairCountsNew = std.AutoHashMap(u32, usize).init(self.allocator);
        errdefer pairCountsNew.deinit();

        for (pairs.items) |pair| {
            const gop = try pairCountsNew.getOrPut(pair);
            if (!gop.found_existing) {
                gop.value_ptr.* = 1;
            } else {
                gop.value_ptr.* += 1;
            }
        }

        return pairCountsNew;
    }

    fn sortCodePointPairs(self: *BasicTokenizer, pairCounts: std.AutoHashMap(u32, usize), stats: *TimeStats) ![]PairCount {
        const start = std.time.milliTimestamp();
        defer {
            const end = std.time.milliTimestamp();
            stats.sort_pairs_time += end - start;
            stats.sort_pairs_calls += 1;
        }

        var sortedPairs = try self.allocator.alloc(PairCount, pairCounts.count());
        errdefer self.allocator.free(sortedPairs);

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

    fn printMergeInfo(_: *BasicTokenizer, currentIndex: u16, vocabSize: u16, topCodePointPair: PairCount) void {
        std.debug.print("merge {d}/{d}: ({d},{d}) -> {d} had {d} occurrences\n", .{
            currentIndex - vocabStart + 1,
            vocabSize - vocabStart,
            @as(u16, @truncate(topCodePointPair.pair >> 16)),
            @as(u16, @truncate(topCodePointPair.pair & 0xFFFF)),
            currentIndex,
            topCodePointPair.count,
        });
    }
};
