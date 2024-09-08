const std = @import("std");

// import read_file
const readFile = @import("read_file.zig").readFile;

pub fn countTextSize(comptime path: []const u8) comptime_int {
    const text = @embedFile(path);
    return text.len;
}
