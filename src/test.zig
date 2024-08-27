const std = @import("std");

pub fn main() !void {
    const my_test = "é";
    try getTokensFromString(my_test);
}

pub fn getTokensFromString(text: []const u8) !void {
    var utf8 = try std.unicode.Utf8View.init(text);
    var iter = utf8.iterator();

    while (iter.nextCodepointSlice()) |byte_slice| {
        for (byte_slice) |byte| {
            std.debug.print("UTF-8 byte: {}\n", .{byte});
        }
    }
}
