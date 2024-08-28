const std = @import("std");

const ArenaAllocator = std.heap.ArenaAllocator;
fn initArena(backing_allocator: std.mem.Allocator) !ArenaAllocator {
    return ArenaAllocator.init(backing_allocator);
}

pub const Vocab = std.AutoHashMap(u16, []const u8);

pub const CharPair = struct {
    first: u16,
    second: u16,

    pub fn asSlice(self: CharPair) [2]u16 {
        return .{ self.first, self.second };
    }
};

pub const CharPairFrequencies = struct {
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

pub const Merge = struct {
    pair: CharPair,
    new_token: u16,
};

pub const TokenPair = struct {
    tokens: []const u16,
    index: usize,

    pub fn slice(self: TokenPair) []const u16 {
        return self.tokens[self.index .. self.index + 2];
    }
};

pub const TrainResult = struct {
    tokens: std.ArrayList(u16),
    merges: std.ArrayList(Merge),
};

pub fn main() !void {
    const backing_allocator = std.heap.page_allocator;
    var arena = try initArena(backing_allocator);
    defer arena.deinit();

    var basic_tokenizer = try BasicTokenizer.init(backing_allocator);
    defer basic_tokenizer.deinit();

    const text = try readFile(&arena, "taylorswift.txt");
    // No need to free text, as it will be freed when arena is deinitialized
    try basic_tokenizer.train(text, 1000);

    const test_text = "The official name for the encoding is UTF-8, the spelling used in all Unicode Consortium documents. Most standards officially list it in upper case as well, but all that do are also case-insensitive and utf-8 is often used in code.[citation needed]Some other spellings may also be accepted by standards, e.g. web standards (which include CSS, HTML, XML, and HTTP headers) explicitly allow utf8 (and disallow unicode) and many aliases for encodings.[10] Spellings with a space e.g. UTF 8 should not be used. The official Internet Assigned Numbers Authority also lists csUTF8 as the only alias,[11] which is rarely used.In Windows, UTF-8 is codepage 65001[12] (i.e. CP_UTF8 in source code).In MySQL, UTF-8 is called utf8mb4[13] (with utf8mb3, and its alias utf8, being a subset encoding for characters in the Basic Multilingual Plane[14]).In HP PCL, the Symbol-ID for UTF-8 is 18N.[15]In Oracle Database (since version 9.0), AL32UTF8[16] means UTF-8. See also CESU-8 for an almost synonym with UTF-8 that rarely should be used.UTF-8-BOM and UTF-8-NOBOM are sometimes used for text files which contain or do not contain a byte-order mark (BOM), respectively.[citation needed] In Japan especially, UTF-8 encoding without a BOM is sometimes called UTF-8N.[17][18]";
    const test_text_tokens = try basic_tokenizer.generateInitialTokens(test_text);
    defer test_text_tokens.deinit();

    std.debug.print("Original text token count: {any}\n", .{test_text_tokens.items.len});

    const encoded = try basic_tokenizer.encode(test_text);
    std.debug.print("Encoded token count: {any}\n", .{encoded.len});

    const decoded = try basic_tokenizer.decode(encoded);

    // use mem eql on the original text and the decoded text
    std.debug.print("Text matches: {any}\n", .{std.mem.eql(u8, test_text, decoded)});

    // print the ratio of the original token count to the encoded token count
    std.debug.print("Token ratio: {d}\n", .{@as(f32, @floatFromInt(test_text_tokens.items.len)) / @as(f32, @floatFromInt(encoded.len))});
}

pub const BasicTokenizer = struct {
    tokens: std.ArrayList(u16),
    merges: std.ArrayList(Merge),
    vocab: Vocab,
    arena: ArenaAllocator,

    pub fn init(backing_allocator: std.mem.Allocator) !@This() {
        var arena = try initArena(backing_allocator);
        errdefer arena.deinit();

        return .{
            .tokens = std.ArrayList(u16).init(arena.allocator()),
            .merges = std.ArrayList(Merge).init(arena.allocator()),
            .vocab = Vocab.init(arena.allocator()),
            .arena = arena,
        };
    }

    pub fn deinit(self: *BasicTokenizer) void {
        self.tokens.deinit();
        self.merges.deinit();
        self.vocab.deinit();
        self.arena.deinit();
    }

    pub fn train(self: *BasicTokenizer, text: []const u8, comptime vocab_size: u16) !void {
        const result = try self.expandVocabulary(text, vocab_size);
        self.tokens = result.tokens;
        self.merges = result.merges;
        self.vocab = try self.createVocab(&self.merges);
    }

    pub fn encode(self: *BasicTokenizer, text: []const u8) ![]u16 {
        var encoded = std.ArrayList(u16).init(self.arena.allocator());
        errdefer encoded.deinit();

        var i: usize = 0;
        while (i < text.len) {
            var best_match: ?struct { token: u16, length: usize } = null;

            // Try to find the longest matching sequence
            var it = self.vocab.iterator();
            while (it.next()) |entry| {
                const token_bytes = entry.value_ptr.*;
                if (text.len - i >= token_bytes.len and std.mem.eql(u8, token_bytes, text[i .. i + token_bytes.len])) {
                    if (best_match == null or token_bytes.len > best_match.?.length) {
                        best_match = .{ .token = entry.key_ptr.*, .length = token_bytes.len };
                    }
                }
            }

            if (best_match) |match| {
                try encoded.append(match.token);
                i += match.length;
            } else {
                // If no match found, encode as a single byte
                try encoded.append(text[i]);
                i += 1;
            }
        }

        return encoded.toOwnedSlice();
    }

    pub fn decode(self: *BasicTokenizer, tokens: []const u16) ![]u8 {
        var result = std.ArrayList(u8).init(self.arena.allocator());
        errdefer result.deinit();

        for (tokens) |token| {
            const bytes = self.vocab.get(token) orelse return error.InvalidToken;
            try result.appendSlice(bytes);
        }

        return result.toOwnedSlice();
    }

    fn generateInitialTokens(self: *BasicTokenizer, text: []const u8) !std.ArrayList(u16) {
        var tokens = std.ArrayList(u16).init(self.arena.allocator());
        var utf8 = try std.unicode.Utf8View.init(text);
        var iter = utf8.iterator();

        while (iter.nextCodepointSlice()) |byte_slice| {
            try tokens.append(byte_slice[0]);
        }

        return tokens;
    }

    fn createVocab(self: *BasicTokenizer, merges: *const std.ArrayList(Merge)) !Vocab {
        var vocab = Vocab.init(self.arena.allocator());

        // Initialize with byte values
        for (0..256) |i| {
            const byte_slice = try self.arena.allocator().dupe(u8, &[_]u8{@intCast(i)});
            try vocab.put(@intCast(i), byte_slice);
        }

        // Add merged pairs
        for (merges.items) |merge| {
            const p0 = vocab.get(merge.pair.first) orelse return error.InvalidMerge;
            const p1 = vocab.get(merge.pair.second) orelse return error.InvalidMerge;

            var combined = try self.arena.allocator().alloc(u8, p0.len + p1.len);
            @memcpy(combined[0..p0.len], p0);
            @memcpy(combined[p0.len..], p1);

            try vocab.put(merge.new_token, combined);
        }

        return vocab;
    }

    fn countCharPairFrequencies(self: *BasicTokenizer, utf8_bytes: []const u16) !CharPairFrequencies {
        var frequencies = CharPairFrequencies.init(self.arena.allocator());
        errdefer frequencies.deinit();

        var i: usize = 0;
        while (i < utf8_bytes.len - 1) {
            const char1 = utf8_bytes[i];
            const char2 = utf8_bytes[i + 1];
            const pair = CharPair{ .first = char1, .second = char2 };

            const entry = try frequencies.frequencies.getOrPut(pair);
            if (entry.found_existing) {
                entry.value_ptr.* += 1;
            } else {
                entry.value_ptr.* = 1;
            }

            i += 1;
        }

        return frequencies;
    }

    fn findMostFrequentPair(stats: CharPairFrequencies) !CharPair {
        var iterator = stats.frequencies.iterator();
        var top_pair: CharPair = undefined;
        var top_value: usize = 0;
        while (iterator.next()) |entry| {
            if (entry.value_ptr.* > top_value) {
                top_value = entry.value_ptr.*;
                top_pair = entry.key_ptr.*;
            }
        }
        return top_pair;
    }

    fn replaceTopPairWithIndex(self: *BasicTokenizer, tokens: []const u16, top_pair: CharPair, index: u16) !std.ArrayList(u16) {
        var new_tokens = std.ArrayList(u16).init(self.arena.allocator());
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

    fn isMatchingPairAtIndex(tokens: []const u16, index: usize, pair: CharPair) bool {
        if (tokens.len - index < 2) return false;

        const tokenPair = TokenPair{ .tokens = tokens, .index = index };
        const slice = tokenPair.slice();
        return std.mem.eql(u16, slice, &[_]u16{ pair.first, pair.second });
    }

    fn expandVocabulary(self: *BasicTokenizer, text: []const u8, comptime target_vocab_size: u16) !TrainResult {
        var current_tokens = std.ArrayList(u16).init(self.arena.allocator());
        errdefer current_tokens.deinit();
        const initial_tokens = try self.generateInitialTokens(text);
        defer initial_tokens.deinit();
        try current_tokens.appendSlice(initial_tokens.items);

        var merges = std.ArrayList(Merge).init(self.arena.allocator());
        errdefer merges.deinit();

        comptime var current_index: u16 = 256;

        inline while (current_index < target_vocab_size) : (current_index += 1) {
            var stats = try self.countCharPairFrequencies(current_tokens.items);
            defer stats.deinit();
            const top_pair = try findMostFrequentPair(stats);
            try merges.append(.{ .pair = top_pair, .new_token = current_index });

            const new_tokens = try self.replaceTopPairWithIndex(current_tokens.items, top_pair, current_index);
            current_tokens.deinit();
            current_tokens = new_tokens;
        }

        return TrainResult{ .tokens = current_tokens, .merges = merges };
    }
};
pub fn readFile(arena: *ArenaAllocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try arena.allocator().alloc(u8, file_size);

    const bytes_read = try file.readAll(buffer);
    if (bytes_read < file_size) {
        return error.UnexpectedEOF;
    }

    return buffer;
}
