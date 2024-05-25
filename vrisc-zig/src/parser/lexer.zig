const std = @import("std");
const ast = @import("./ast.zig");

const LexingError = error {
    UnknownCharacter
} || std.fmt.ParseIntError || std.mem.Allocator.Error;

// aka. lexer
pub fn parseTokens(content: []const u8) LexingError![]ast.Token {
    var tokens = std.ArrayList(ast.Token).init(std.heap.page_allocator);
    var cur_idx: usize = 0;
    var cur_word_len: usize = 0;
    var is_number = false;
    while (cur_idx < content.len) {
        switch (content[cur_idx]) {
            'a' ... 'z', 'A' ... 'Z' => cur_word_len += 1,
            '0' ... '9' => {
                if(cur_word_len == 0) {
                    is_number = true;
                }
                cur_word_len += 1;
            },
            '.', '#', ',' => |ctrl| {
                if(cur_word_len != 0) {
                    const word_start = cur_idx - cur_word_len;
                    const word = content[word_start..cur_idx];
                    if(is_number) {
                        const num = try std.fmt.parseInt(usize, word, 10);
                        try tokens.append(.{
                            .number = num
                        });
                    } else {
                        try tokens.append(.{ .identifier = word });
                    }
                    cur_word_len = 0;
                    is_number = false;
                }
                try tokens.append(.{ .control = ctrl });
            },
            ' ', '\n' => {
                if(cur_word_len != 0) {
                    const word_start = cur_idx - cur_word_len;
                    const word = content[word_start..cur_idx];
                    if(is_number) {
                        const num = try std.fmt.parseInt(usize, word, 10);
                        try tokens.append(.{
                            .number = num
                        });
                    } else {
                        try tokens.append(.{ .identifier = word });
                    }
                    cur_word_len = 0;
                    is_number = false;
                }
            },
            else => return LexingError.UnknownCharacter,
        }
        cur_idx += 1;
    }
    const tokens_slice = tokens.toOwnedSlice();
    // Unnecessary but you never know
    tokens.deinit();
    return tokens_slice;
}