const std = @import("std");
const Allocator = std.mem.Allocator;

pub const TimeStats = struct {
    allocator: Allocator,
    sort_pairs_time: i64,
    sort_pairs_calls: usize,
    replace_pair_time: i64,
    replace_pair_calls: usize,
    generate_pairs_time: i64,
    generate_pairs_calls: usize,
    just_count_pairs_time: i64,
    just_count_pairs_calls: usize,

    pub fn init(allocator: Allocator) !*TimeStats {
        const self = try allocator.create(TimeStats);
        self.* = .{
            .allocator = allocator,
            .sort_pairs_time = 0,
            .sort_pairs_calls = 0,
            .replace_pair_time = 0,
            .replace_pair_calls = 0,
            .generate_pairs_time = 0,
            .generate_pairs_calls = 0,
            .just_count_pairs_time = 0,
            .just_count_pairs_calls = 0,
        };
        return self;
    }

    pub fn deinit(self: *TimeStats) void {
        self.allocator.destroy(self);
    }
};

pub fn printTimeStats(stats: *const TimeStats, total_time: i64) void {
    std.debug.print("\nTime statistics:\n", .{});
    std.debug.print("sortCodePointPairs: {d:.3}s total, {d} calls, {d:.3}s avg\n", .{
        @as(f64, @floatFromInt(stats.sort_pairs_time)) / 1000.0,
        stats.sort_pairs_calls,
        @as(f64, @floatFromInt(stats.sort_pairs_time)) / (@as(f64, @floatFromInt(stats.sort_pairs_calls)) * 1000.0),
    });
    std.debug.print("replaceTopPairWithIndex: {d:.3}s total, {d} calls, {d:.3}s avg\n", .{
        @as(f64, @floatFromInt(stats.replace_pair_time)) / 1000.0,
        stats.replace_pair_calls,
        @as(f64, @floatFromInt(stats.replace_pair_time)) / (@as(f64, @floatFromInt(stats.replace_pair_calls)) * 1000.0),
    });
    std.debug.print("generateCodePointPairs: {d:.3}s total, {d} calls, {d:.3}s avg\n", .{
        @as(f64, @floatFromInt(stats.generate_pairs_time)) / 1000.0,
        stats.generate_pairs_calls,
        @as(f64, @floatFromInt(stats.generate_pairs_time)) / (@as(f64, @floatFromInt(stats.generate_pairs_calls)) * 1000.0),
    });
    std.debug.print("countPointPairs: {d:.3}s total, {d} calls, {d:.3}s avg\n", .{
        @as(f64, @floatFromInt(stats.just_count_pairs_time)) / 1000.0,
        stats.just_count_pairs_calls,
        @as(f64, @floatFromInt(stats.just_count_pairs_time)) / (@as(f64, @floatFromInt(stats.just_count_pairs_calls)) * 1000.0),
    });
    const other_time = total_time - stats.sort_pairs_time - stats.replace_pair_time - stats.generate_pairs_time - stats.just_count_pairs_time;
    std.debug.print("Other operations: {d:.3}s\n", .{@as(f64, @floatFromInt(other_time)) / 1000.0});
}
