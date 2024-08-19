pub const DEFAULT_INDEX = 256;
pub const INPUT_FILE_PATH = "input.txt";

pub const CharPair = struct {
    first: u16,
    second: u16,

    pub fn asSlice(self: CharPair) [2]u16 {
        return .{ self.first, self.second };
    }
};

pub const TokenPair = struct {
    tokens: []const u16,
    index: usize,

    pub fn slice(self: TokenPair) []const u16 {
        return self.tokens[self.index .. self.index + 2];
    }
};

pub const StatEntry = struct {
    key: CharPair,
    value: usize,
};

pub const Merge = struct {
    pair: CharPair,
    new_token: u16,
};