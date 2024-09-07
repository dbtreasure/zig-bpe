const std = @import("std");

pub fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);

    const bytes_read = try file.readAll(buffer);
    if (bytes_read < file_size) {
        return error.UnexpectedEOF;
    }

    return buffer;
}
