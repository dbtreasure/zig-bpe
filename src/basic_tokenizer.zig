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
    merges: std.ArrayList(Merge),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) @This() {
        return .{
            .merges = std.ArrayList(Merge).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Merges) void {
        self.merges.deinit();
    }

    pub fn put(self: *Merges, pair: CharPair, new_token: u16) !void {
        try self.merges.append(.{
            .pair = pair,
            .new_token = new_token,
        });
    }
};

const CharPair = struct {
    first: u16,
    second: u16,
};

const PairCount = struct {
    pair: CharPair,
    count: usize,
};

const vocabStart: u16 = 256;

pub const BasicTokenizer = struct {
    allocator: std.mem.Allocator,
    timeStats: *TimeStats,
    merges: Merges,

    pub fn init(allocator: std.mem.Allocator) !@This() {
        const timeStats = try TimeStats.init(allocator);
        return .{
            .allocator = allocator,
            .timeStats = timeStats,
            .merges = Merges.init(allocator),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.timeStats.deinit();
        self.merges.deinit();
    }

    pub fn encode(self: *@This(), text: []const u8) !std.ArrayList(u16) {
        var tokens = try self.generateInitialTokens(text);
        errdefer tokens.deinit();

        for (self.merges.merges.items) |merge| {
            var i: usize = 0;
            while (i < tokens.items.len) {
                if (i + 1 < tokens.items.len and tokens.items[i] == merge.pair.first and tokens.items[i + 1] == merge.pair.second) {
                    tokens.items[i] = merge.new_token;
                    _ = tokens.orderedRemove(i + 1);
                } else {
                    i += 1;
                }
            }
        }

        return tokens;
    }

    pub fn decode(self: *@This(), tokens: std.ArrayList(u16)) ![]u8 {
        var decoded = std.ArrayList(u8).init(self.allocator);
        errdefer decoded.deinit();

        for (tokens.items) |token| {
            if (token < 256) {
                try decoded.append(@truncate(token));
            } else {
                if (self.findMerge(token)) |merge| {
                    try self.decodeMerge(merge, &decoded);
                } else {
                    return error.InvalidToken;
                }
            }
        }

        return decoded.toOwnedSlice();
    }

    fn findMerge(self: *@This(), token: u16) ?Merge {
        for (self.merges.merges.items) |merge| {
            if (merge.new_token == token) {
                return merge;
            }
        }
        return null;
    }

    fn decodeMerge(self: *@This(), merge: Merge, decoded: *std.ArrayList(u8)) !void {
        if (merge.pair.first < 256) {
            try decoded.append(@truncate(merge.pair.first));
        } else {
            if (self.findMerge(merge.pair.first)) |subMerge| {
                try self.decodeMerge(subMerge, decoded);
            } else {
                return error.InvalidToken;
            }
        }

        if (merge.pair.second < 256) {
            try decoded.append(@truncate(merge.pair.second));
        } else {
            if (self.findMerge(merge.pair.second)) |subMerge| {
                try self.decodeMerge(subMerge, decoded);
            } else {
                return error.InvalidToken;
            }
        }
    }

    pub fn train(self: *@This(), text: []const u8, vocabSize: u16, verbose: bool) TrainError!void {
        const start = std.time.milliTimestamp();
        defer {
            const end = std.time.milliTimestamp();
            printTimeStats(self.timeStats, end - start);
        }

        if (vocabSize < 256) {
            return TrainError.InvalidVocabSize;
        }
        const tokens = try self.generateInitialTokens(text);
        defer tokens.deinit();
        try self.expandVocabulary(tokens, vocabSize, verbose);
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

    fn expandVocabulary(self: *BasicTokenizer, tokens: std.ArrayList(u16), vocabSize: u16, verbose: bool) TrainError!void {
        var currentTokens = try std.ArrayList(u16).initCapacity(self.allocator, tokens.items.len);
        try currentTokens.appendSlice(tokens.items);
        defer currentTokens.deinit();

        var currentIndex: u16 = vocabStart;

        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const aa = arena.allocator();

        while (currentIndex < vocabSize) : (currentIndex += 1) {
            var codePointPairs = try self.generateCodePointPairs(&currentTokens, self.timeStats, aa);
            const codePointPairCounts = try self.countCodePointPairs(&codePointPairs, self.timeStats, aa);
            const sortedCodePointPairs = try self.sortCodePointPairs(codePointPairCounts, self.timeStats, aa);

            if (sortedCodePointPairs.len == 0) {
                std.debug.print("No more pairs to merge. Stopping early.\n", .{});
                break;
            }

            const topCodePointPair = sortedCodePointPairs[0];

            if (verbose) {
                self.printMergeInfo(currentIndex, vocabSize, topCodePointPair);
            }

            try self.merges.put(topCodePointPair.pair, currentIndex);

            try replaceTopPairWithNewToken(&currentTokens, topCodePointPair, currentIndex, self.timeStats);

            _ = arena.reset(.free_all);
        }
    }

    fn replaceTopPairWithNewToken(tokens: *std.ArrayList(u16), pairCount: PairCount, newToken: u16, stats: *TimeStats) TrainError!void {
        const start = std.time.milliTimestamp();
        defer {
            const end = std.time.milliTimestamp();
            stats.replace_pair_time += end - start;
            stats.replace_pair_calls += 1;
        }

        var i: usize = 0;
        var j: usize = 0;
        while (i < tokens.items.len - 1) {
            if (tokens.items[i] == pairCount.pair.first and tokens.items[i + 1] == pairCount.pair.second) {
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

    fn generateCodePointPairs(_: *BasicTokenizer, tokens: *std.ArrayList(u16), stats: *TimeStats, allocator: std.mem.Allocator) !std.ArrayList(CharPair) {
        const start = std.time.milliTimestamp();
        defer {
            const end = std.time.milliTimestamp();
            stats.generate_pairs_time += end - start;
            stats.generate_pairs_calls += 1;
        }

        var pairs = std.ArrayList(CharPair).init(allocator);
        errdefer pairs.deinit();

        var i: usize = 0;
        while (i < tokens.items.len - 1) : (i += 1) {
            const charPair = CharPair{
                .first = tokens.items[i],
                .second = tokens.items[i + 1],
            };
            try pairs.append(charPair);
        }

        return pairs;
    }

    fn countCodePointPairs(_: *BasicTokenizer, pairs: *std.ArrayList(CharPair), stats: *TimeStats, allocator: std.mem.Allocator) !std.AutoHashMap(CharPair, usize) {
        const start = std.time.milliTimestamp();
        defer {
            const end = std.time.milliTimestamp();
            stats.just_count_pairs_time += end - start;
            stats.just_count_pairs_calls += 1;
        }

        var pairCountsNew = std.AutoHashMap(CharPair, usize).init(allocator);
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

    fn sortCodePointPairs(_: *BasicTokenizer, pairCounts: std.AutoHashMap(CharPair, usize), stats: *TimeStats, allocator: std.mem.Allocator) ![]PairCount {
        const start = std.time.milliTimestamp();
        defer {
            const end = std.time.milliTimestamp();
            stats.sort_pairs_time += end - start;
            stats.sort_pairs_calls += 1;
        }

        var sortedPairs = try allocator.alloc(PairCount, pairCounts.count());

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

    fn printMergeInfo(_: *BasicTokenizer, currentIndex: u16, vocabSize: u16, topPairCount: PairCount) void {
        std.debug.print("merge {d}/{d}: ({d},{d}) -> {d} had {d} occurrences\n", .{
            currentIndex - vocabStart + 1,
            vocabSize - vocabStart,
            topPairCount.pair.first,
            topPairCount.pair.second,
            currentIndex,
            topPairCount.count,
        });
    }

    pub fn serializeMerges(self: *@This(), file_path: []const u8) !void {
        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();

        var writer = file.writer();

        for (self.merges.merges.items) |entry| {
            const pair = entry.pair;
            const new_token = entry.new_token;
            try writer.print("{d},{d},{d}\n", .{ pair.first, pair.second, new_token });
        }
    }

    pub fn deserializeMerges(self: *@This(), file_path: []const u8) !void {
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        var buf: [100]u8 = undefined;
        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            var it = std.mem.split(u8, line, ",");
            const first = try std.fmt.parseInt(u16, it.next() orelse return error.InvalidFormat, 10);
            const second = try std.fmt.parseInt(u16, it.next() orelse return error.InvalidFormat, 10);
            const new_token = try std.fmt.parseInt(u16, it.next() orelse return error.InvalidFormat, 10);

            try self.merges.put(.{ .first = first, .second = second }, new_token);
        }
    }
};

test "generateInitialTokens" {
    var tokenizer = try BasicTokenizer.init(std.testing.allocator);
    defer tokenizer.deinit();

    const text = "hello world";

    const tokens = try tokenizer.generateInitialTokens(text);
    defer tokens.deinit();
    try std.testing.expectEqualSlices(u16, &.{ 'h', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd' }, tokens.items);
}

test "encode" {
    var tokenizer = try BasicTokenizer.init(std.testing.allocator);
    defer tokenizer.deinit();

    // Add some merges to the tokenizer
    try tokenizer.merges.put(.{ .first = 'h', .second = 'e' }, 256);
    try tokenizer.merges.put(.{ .first = 256, .second = 'l' }, 257);
    try tokenizer.merges.put(.{ .first = 'w', .second = 'o' }, 258);

    const text = "hello world";
    const encoded = try tokenizer.encode(text);
    defer encoded.deinit();

    // Expected tokens: [257, 'l', 'o', ' ', 258, 'r', 'l', 'd']
    const expected = [_]u16{ 257, 'l', 'o', ' ', 258, 'r', 'l', 'd' };
    try std.testing.expectEqualSlices(u16, &expected, encoded.items);
}

test "decode" {
    var tokenizer = try BasicTokenizer.init(std.testing.allocator);
    defer tokenizer.deinit();

    // Add some merges to the tokenizer
    try tokenizer.merges.put(.{ .first = 'h', .second = 'e' }, 256);
    try tokenizer.merges.put(.{ .first = 256, .second = 'l' }, 257);
    try tokenizer.merges.put(.{ .first = 'w', .second = 'o' }, 258);

    var tokens = std.ArrayList(u16).init(std.testing.allocator);
    defer tokens.deinit();
    try tokens.appendSlice(&[_]u16{ 257, 'l', 'o', ' ', 258, 'r', 'l', 'd' });

    const decoded = try tokenizer.decode(tokens);
    defer std.testing.allocator.free(decoded);

    try std.testing.expectEqualStrings("hello world", decoded);
}

test "train" {
    var tokenizer = try BasicTokenizer.init(std.testing.allocator);
    defer tokenizer.deinit();

    const text = "hello world hello";
    const vocabSize: u16 = 300;

    try tokenizer.train(text, vocabSize, true);

    // Check if merges were created
    try std.testing.expect(tokenizer.merges.merges.items.len > 0);

    // Encode a test string and check the result
    const encoded = try tokenizer.encode("hello");
    defer encoded.deinit();

    // Print the encoded result for debugging
    std.debug.print("Encoded result: ", .{});
    for (encoded.items) |token| {
        std.debug.print("{} ", .{token});
    }
    std.debug.print("\n", .{});

    // Check the length of the encoded result
    try std.testing.expect(encoded.items.len == 1);

    // Check the specific token
    try std.testing.expect(encoded.items[0] == 259);

    // Decode the encoded string and check the result
    const decoded = try tokenizer.decode(encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualStrings("hello", decoded);
}
