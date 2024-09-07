const std = @import("std");

// import read_file
const readFile = @import("read_file.zig").readFile;

pub fn countTextSize(allocator: std.mem.Allocator, path: []const u8) !usize {
    const text = try readFile(allocator, path);
    return text.len;
}
