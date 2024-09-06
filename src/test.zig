const std = @import("std");
const Allocator = std.mem.Allocator;

fn allocLower(allocator: Allocator, str: []const u8) ![]const u8 {
    var dest = try allocator.alloc(u8, str.len);

    for (str, 0..) |c, i| {
        dest[i] = switch (c) {
            'A'...'Z' => c + 32,
            else => c,
        };
    }

    return dest;
}

fn isSpecial(allocator: Allocator, name: []const u8) !bool {
    const lower = try allocLower(allocator, name);
    return std.mem.eql(u8, lower, "admin");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const check = gpa.deinit();
        if (check == .leak) {
            std.debug.print("Memory leak detected!\n", .{});
        }
    }
    const allocator = gpa.allocator();

    const str = "Hello, world!";

    // check if the string is special
    const is_special = try isSpecial(allocator, str);
    if (is_special) {
        std.debug.print("The string is special!\n", .{});
    } else {
        std.debug.print("The string is not special!\n", .{});
    }
}
