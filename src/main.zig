const rl = @import("raylib");
const std = @import("std");
const readFile = @import("utils/read_file.zig").readFile;
const BasicTokenizer = @import("basic_tokenizer.zig").BasicTokenizer;
const TrainError = @import("basic_tokenizer.zig").TrainError;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tokenizer = try BasicTokenizer.init(allocator);
    defer tokenizer.deinit();

    const text = try readFile(allocator, "taylorswift.txt");
    defer allocator.free(text);

    const start_time = std.time.milliTimestamp();

    try tokenizer.train(text, 300, false);
    try tokenizer.serializeMerges("merges.txt");

    // try tokenizer.deserializeMerges("merges.txt");
    const tokens = try tokenizer.encode("hello world!!!? (안녕하세요!) lol123 😉");
    defer tokens.deinit();

    for (tokens.items) |token| {
        std.debug.print("{d} ", .{token});
    }

    const decoded = try tokenizer.decode(tokens);
    defer allocator.free(decoded);

    std.debug.print("\n{s}\n", .{decoded});

    const end_time = std.time.milliTimestamp();
    const duration_ms = end_time - start_time;

    std.debug.print("Training completed in {d} ms\n", .{duration_ms});
}

test "serializeMerges and deserializeMerges" {
    var tokenizer = try BasicTokenizer.init(std.testing.allocator);
    defer tokenizer.deinit();

    // Add some test merges
    try tokenizer.merges.put(.{ .first = 'h', .second = 'e' }, 256);
    try tokenizer.merges.put(.{ .first = 256, .second = 'l' }, 257);
    try tokenizer.merges.put(.{ .first = 'w', .second = 'o' }, 258);

    // Serialize merges
    const test_file = "test_merges.txt";
    try tokenizer.serializeMerges(test_file);
    defer std.fs.cwd().deleteFile(test_file) catch {};

    // Create a new tokenizer and deserialize merges
    var new_tokenizer = try BasicTokenizer.init(std.testing.allocator);
    defer new_tokenizer.deinit();

    try new_tokenizer.deserializeMerges(test_file);

    // Check if deserialized merges match the original
    try std.testing.expectEqual(tokenizer.merges.merges.items.len, new_tokenizer.merges.merges.items.len);
    for (tokenizer.merges.merges.items, 0..) |merge, i| {
        try std.testing.expectEqual(merge.pair.first, new_tokenizer.merges.merges.items[i].pair.first);
        try std.testing.expectEqual(merge.pair.second, new_tokenizer.merges.merges.items[i].pair.second);
        try std.testing.expectEqual(merge.new_token, new_tokenizer.merges.merges.items[i].new_token);
    }
}
