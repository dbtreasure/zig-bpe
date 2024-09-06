const AutoHashMap = std.AutoHashMap;

const std = @import("std");

pub fn hasTwoSum(array: []const i32, target: i32) bool {
    var seen = AutoHashMap(i32, void).init(std.heap.page_allocator);
    defer seen.deinit();

    for (array) |num| {
        const complement = target - num;
        if (seen.contains(complement)) {
            return true;
        }
        seen.put(num, {}) catch |err| {
            std.debug.print("Error inserting into hash map: {}\n", .{err});
            return false;
        };
    }

    return false;
}

pub fn main() !void {
    const unsortedArray = [_]i32{ 9, 2, 11, 7, 15, 4, 5, 8 };

    const result1 = hasTwoSum(&unsortedArray, 13);
    std.debug.print("Result for target 13: {}\n", .{result1});

    const result2 = hasTwoSum(&unsortedArray, 3);
    std.debug.print("Result for target 3: {}\n", .{result2});

    const result3 = hasTwoSum(&unsortedArray, 23);
    std.debug.print("Result for target 23: {}\n", .{result3});
}
