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
    time_stats: TimeStats,

    const TimeStats = struct {
        sort_pairs_time: i64 = 0,
        sort_pairs_calls: usize = 0,
        replace_pair_time: i64 = 0,
        replace_pair_calls: usize = 0,
        generate_pairs_time: i64 = 0,
        generate_pairs_calls: usize = 0,
        just_count_pairs_time: i64 = 0,
        just_count_pairs_calls: usize = 0,
    };

    pub fn init(allocator: std.mem.Allocator) !@This() {
        return .{
            .allocator = allocator,
            .tokens = std.ArrayList(u16).init(allocator),
            .time_stats = TimeStats{},
        };
    }

    pub fn deinit(self: *@This()) void {
        self.tokens.deinit();
    }

    pub fn train(self: *@This(), text: []const u8, vocabSize: u16) TrainError!void {
        const start = std.time.milliTimestamp();
        defer {
            const end = std.time.milliTimestamp();
            const total_time = end - start;
            self.printTimeStats(total_time);
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
        const start = std.time.milliTimestamp();
        defer {
            const end = std.time.milliTimestamp();
            std.debug.print("expandVocabulary runtime: {d:.3} seconds\n", .{@as(f64, @floatFromInt(end - start)) / 1000.0});
        }

        var currentTokens = try std.ArrayList(u16).initCapacity(self.allocator, tokens.items.len);
        try currentTokens.appendSlice(tokens.items);
        defer currentTokens.deinit();

        var merges = Merges.init(self.allocator);
        defer merges.deinit();

        std.debug.print("vocab len: {}\n", .{vocabSize});

        var currentIndex: u16 = vocabStart;
        while (currentIndex < vocabSize) : (currentIndex += 1) {
            var codePointPairs = try self.generateCodePointPairs(&currentTokens, &self.time_stats);
            defer codePointPairs.deinit();
            var codePointPairCounts = try self.countPointPairs(&codePointPairs, &self.time_stats);
            defer codePointPairCounts.deinit();
            const sortedCodePointPairs = try self.sortCodePointPairs(codePointPairCounts, &self.time_stats);
            defer self.allocator.free(sortedCodePointPairs);

            const topCodePointPair = sortedCodePointPairs[0];

            try merges.put(topCodePointPair, currentIndex);

            // Add this print statement
            // std.debug.print("merge {d}/{d}: ({d},{d}) -> {d} had {d} occurrences\n", .{
            //     currentIndex - vocabStart + 1,
            //     vocabSize - vocabStart,
            //     charPair.first,
            //     charPair.second,
            //     currentIndex,
            //     topPair.count,
            // });

            try replaceTopPairWithNewToken(&currentTokens, topCodePointPair, currentIndex, &self.time_stats);
        }

        try self.tokens.appendSlice(currentTokens.items);
    }

    fn replaceTopPairWithNewToken(tokens: *std.ArrayList(u16), pair: PairCount, newToken: u16, stats: *BasicTokenizer.TimeStats) TrainError!void {
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

    fn printTimeStats(self: *BasicTokenizer, total_time: i64) void {
        const stats = &self.time_stats;
        std.debug.print("\nTime statistics:\n", .{});
        std.debug.print("sortCodePointPairs: {d:.3}s total, {d} calls, {d:.3}s avg\n", .{
            @as(f64, @floatFromInt(stats.sort_pairs_time)) / 1000.0,
            stats.sort_pairs_calls,
            @as(f64, @floatFromInt(stats.sort_pairs_time)) / (@as(f64, @floatFromInt(stats.sort_pairs_calls)) * 1000.0),
        });
        std.debug.print("replaceTopPairWithIndex: {d:.3}s total, {d} calls, {d:.3}s avg\n", .{
            @as(f64, @floatFromInt(stats.replace_pair_time)) / 1000.0,
            stats.replace_pair_calls,
            @as(f64, @floatFromInt(stats.replace_pair_time)) / (@as(f64, @floatFromInt(stats.replace_pair_calls)) * 1000.0),
        });
        std.debug.print("generateCodePointPairs: {d:.3}s total, {d} calls, {d:.3}s avg\n", .{
            @as(f64, @floatFromInt(stats.generate_pairs_time)) / 1000.0,
            stats.generate_pairs_calls,
            @as(f64, @floatFromInt(stats.generate_pairs_time)) / (@as(f64, @floatFromInt(stats.generate_pairs_calls)) * 1000.0),
        });
        std.debug.print("countPointPairs: {d:.3}s total, {d} calls, {d:.3}s avg\n", .{
            @as(f64, @floatFromInt(stats.just_count_pairs_time)) / 1000.0,
            stats.just_count_pairs_calls,
            @as(f64, @floatFromInt(stats.just_count_pairs_time)) / (@as(f64, @floatFromInt(stats.just_count_pairs_calls)) * 1000.0),
        });
        const other_time = total_time - stats.sort_pairs_time - stats.replace_pair_time - stats.generate_pairs_time - stats.just_count_pairs_time;
        std.debug.print("Other operations: {d:.3}s\n", .{@as(f64, @floatFromInt(other_time)) / 1000.0});
    }

    fn generateCodePointPairs(self: *BasicTokenizer, tokens: *std.ArrayList(u16), stats: *BasicTokenizer.TimeStats) !std.ArrayList(u32) {
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

    fn countPointPairs(self: *BasicTokenizer, pairs: *std.ArrayList(u32), stats: *BasicTokenizer.TimeStats) !std.AutoHashMap(u32, usize) {
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

    fn sortCodePointPairs(self: *BasicTokenizer, pairCounts: std.AutoHashMap(u32, usize), stats: *BasicTokenizer.TimeStats) ![]PairCount {
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
};
