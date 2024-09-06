const std = @import("std");

const BasicTokenizer = @import("basic_tokenizer.zig").BasicTokenizer;
const TrainError = @import("basic_tokenizer.zig").TrainError;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    var tokenizer = try BasicTokenizer.init(allocator);
    defer tokenizer.deinit();

    // train the tokenizer on some text
    try tokenizer.train(300);
}

test "Tokenizer train vocab size error" {
    // initialize the BasicTokenizer struct
    var tokenizer = try BasicTokenizer.init(std.testing.allocator);
    defer tokenizer.deinit();

    // train the tokenizer on some text
    const result = tokenizer.train(100);
    try std.testing.expectError(TrainError.InvalidVocabSize, result);
}
