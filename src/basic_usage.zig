const std = @import("std");

const readFile = @import("utils/read_file.zig").readFile;
const countTextSize = @import("utils/count_text_size.zig").countTextSize;

const ArenaAllocator = std.heap.ArenaAllocator;
fn initArena(backing_allocator: std.mem.Allocator) !ArenaAllocator {
    return ArenaAllocator.init(backing_allocator);
}

const BasicTokenizer = @import("basic_tokenizer.zig").BasicTokenizer;
const TrainError = @import("basic_tokenizer.zig").TrainError;

pub fn main() !void {
    const backing_allocator = std.heap.page_allocator;
    var arena = try initArena(backing_allocator);
    defer arena.deinit();

    var tokenizer = try BasicTokenizer.init(backing_allocator);
    defer tokenizer.deinit();

    const text = try readFile(arena.allocator(), "taylorswift.txt");

    // const text_size = comptime countTextSize("taylorswift.txt");

    // Start the timer
    const start_time = std.time.milliTimestamp();

    // Use the compile-time text size
    // try tokenizer.train(text, 1000, text_size);
    try tokenizer.train(text, 300);
    // End the timer and calculate the duration
    const end_time = std.time.milliTimestamp();
    const duration_ms = end_time - start_time;

    // Print the duration
    std.debug.print("Training took {} milliseconds\n", .{duration_ms});
}

test "Tokenizer train vocab size error" {
    // initialize the BasicTokenizer struct
    var tokenizer = try BasicTokenizer.init(std.testing.allocator);
    defer tokenizer.deinit();

    // train the tokenizer on some text
    const result = tokenizer.train("hello", 1, 5);
    try std.testing.expectError(TrainError.InvalidVocabSize, result);
}
