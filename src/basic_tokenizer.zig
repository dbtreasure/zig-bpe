const std = @import("std");

pub const TrainError = error{
    InvalidVocabSize,
};

pub const BasicTokenizer = struct {
    tokens: std.ArrayList(u16),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !@This() {
        return .{
            .tokens = std.ArrayList(u16).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *BasicTokenizer) void {
        self.tokens.deinit();
    }

    pub fn train(self: *BasicTokenizer, vocabSize: u16) TrainError!void {
        if (vocabSize < 256) {
            return TrainError.InvalidVocabSize;
        }
        self.tokens = self.tokens;
    }
};
