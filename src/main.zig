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

    const end_time = std.time.milliTimestamp();
    const duration_ms = end_time - start_time;

    std.debug.print("Training completed in {d} ms\n", .{duration_ms});
}
