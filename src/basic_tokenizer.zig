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
    frequencies: std.AutoHashMap(CharPair, usize),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) @This() {
        return .{
            .frequencies = std.AutoHashMap(CharPair, usize).init(allocator),
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
        const tokens = try generateInitialTokens(self.allocator, text);
        try self.expandVocabulary(self.allocator, tokens, vocabSize);
    }

    fn generateInitialTokens(allocator: std.mem.Allocator, text: []const u8) TrainError!std.ArrayList(u16) {
        var tokens = std.ArrayList(u16).init(allocator);
        errdefer tokens.deinit();

        var utf8 = std.unicode.Utf8View.init(text) catch {
            return TrainError.InvalidUtf8;
        };
        var iter = utf8.iterator();

        while (iter.nextCodepointSlice()) |byte_slice| {
            tokens.append(byte_slice[0]) catch {
                return TrainError.OutOfMemory;
            };
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
            try merges.merges.append(.{ .pair = charPair, .new_token = currentIndex });
            try replaceTopPairWithIndex(&currentTokens, charPair, currentIndex);
        }

        try self.tokens.appendSlice(currentTokens.items);
    }

    fn replaceTopPairWithIndex(tokens: *std.ArrayList(u16), pair: CharPair, newToken: u16) TrainError!void {
        var i: usize = 0;
        while (i < tokens.items.len - 1) {
            if (tokens.items[i] == pair.first and tokens.items[i + 1] == pair.second) {
                _ = tokens.orderedRemove(i + 1);
                tokens.items[i] = newToken;
            } else {
                i += 1;
            }
        }
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

    std.mem.sort(PairCount, sortedPairs, {}, comptime lessThan);

    return sortedPairs;
}

fn lessThan(_: void, a: PairCount, b: PairCount) bool {
    return a.count > b.count; // Sort in descending order
}
