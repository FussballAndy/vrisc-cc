const std = @import("std");
const ast = @import("./ast.zig");

const LexingError = error {
    UnknownCharacter,
    NotANumber
} || std.fmt.ParseIntError || std.mem.Allocator.Error;

// aka. lexer
pub fn parseTokens(content: []const u8, allocator: std.mem.Allocator) LexingError![]ast.Token {
    var tokens = std.ArrayList(ast.Token).init(allocator);
    defer tokens.deinit();
    var cur_idx: usize = 0;
    var cur_word_len: usize = 0;
    var is_number = false;
    while (cur_idx < content.len) {
        switch (content[cur_idx]) {
            'a' ... 'z', 'A' ... 'Z' => {
                if(is_number) {
                    return LexingError.NotANumber;
                }
                cur_word_len += 1;
            },
            '0' ... '9' => {
                if(cur_word_len == 0) {
                    is_number = true;
                }
                cur_word_len += 1;
            },
            '.', ',', ':' => |ctrl| {
                if(cur_word_len != 0) {
                    const word_start = cur_idx - cur_word_len;
                    const word = content[word_start..cur_idx];
                    if(is_number) {
                        const num = try std.fmt.parseInt(i64, word, 10);
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
            ' ', '\r', '\n' => {
                if(cur_word_len != 0) {
                    const word_start = cur_idx - cur_word_len;
                    const word = content[word_start..cur_idx];
                    if(is_number) {
                        const num = try std.fmt.parseInt(i64, word, 10);
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
            else => |x|{
                std.debug.print("Error: Unknown character at index {d}: {u}\n", .{cur_idx, x});
                return LexingError.UnknownCharacter;
            },
        }
        cur_idx += 1;
    }
    if(cur_word_len != 0) {
        const word_start = cur_idx - cur_word_len;
        const word = content[word_start..cur_idx];
        if(is_number) {
            const num = try std.fmt.parseInt(i64, word, 10);
            try tokens.append(.{
                .number = num
            });
        } else {
            try tokens.append(.{ .identifier = word });
        }
        cur_word_len = 0;
        is_number = false;
    }
    const tokens_slice = tokens.toOwnedSlice();
    return tokens_slice;
}


test "simple lexer" {
    const Token = ast.Token;
    const testing = std.testing;
    const allocator = testing.allocator;
    const tokens = try parseTokens("mov a, b, c", allocator);
    defer allocator.free(tokens);
    const expected = [_]Token {
        Token{.identifier = "mov"},
        Token{.identifier = "a"},
        Token{.control = ','},
        Token{.identifier = "b"},
        Token{.control = ','},
        Token{.identifier = "c"},
    };
    try testing.expectEqualDeep(&expected, tokens);
}

test "advanced lexer" {
     const Token = ast.Token;
    const testing = std.testing;
    const allocator = testing.allocator;
    const input = 
        \\.comment LOL
        \\start: mov a, b, c
        \\cmp 5, 5
        \\bge start
        \\ret
    ;
    const tokens = try parseTokens(input, allocator);
    defer allocator.free(tokens);
    const expected = [_]Token {
        Token{.control = '.'},
        Token{.identifier = "comment"},
        Token{.identifier = "LOL"},
        Token{.identifier = "start"},
        Token{.control = ':'},
        Token{.identifier = "mov"},
        Token{.identifier = "a"},
        Token{.control = ','},
        Token{.identifier = "b"},
        Token{.control = ','},
        Token{.identifier = "c"},
        Token{.identifier = "cmp"},
        Token{.number = 5},
        Token{.control = ','},
        Token{.number = 5},
        Token{.identifier = "bge"},
        Token{.identifier = "start"},
        Token{.identifier = "ret"}
    };
    try testing.expectEqualDeep(&expected, tokens);

}