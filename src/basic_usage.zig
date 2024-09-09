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

    std.debug.print("Text: {any}\n", .{text.len});
    // Start the timer
    const start_time = std.time.milliTimestamp();

    try tokenizer.train(text, 300);

    // End the timer and calculate the duration
    const end_time = std.time.milliTimestamp();
    const duration_ms = end_time - start_time;

    std.debug.print("Training completed in {d} ms\n", .{duration_ms});
}

test "Tokenizer train vocab size error" {
    // initialize the BasicTokenizer struct
    var tokenizer = try BasicTokenizer.init(std.testing.allocator);
    defer tokenizer.deinit();

    // train the tokenizer on some text
    const result = tokenizer.train("hello", 1, 5);
    try std.testing.expectError(TrainError.InvalidVocabSize, result);
}
