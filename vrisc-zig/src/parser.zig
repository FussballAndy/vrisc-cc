const std = @import("std");
const ast = @import("./ast.zig");
const iter = @import("./iterator.zig");

pub const RuntimeConfig = struct {
    stack_size: u64 = 0,
    entry: u64 = 0,
};

pub const ParserResult = struct {
    instrs: std.ArrayList(ast.Expr),
    config: RuntimeConfig,
};

const ParserError = error {
    UnexpectedToken,
    UnexpectedEOF,
    MultiConfig
};

pub fn parse_expr(tokens: []ast.Token) ParserError!void {
    var result: ParserResult = .{
        .instrs = std.ArrayList(ast.Expr).init(std.heap.page_allocator)
    };
    var tokens_iter = iter.SliceIterator(ast.Token) { .inner = tokens };

    while (tokens_iter.has_next()) {
        try p_instr_cfg_label(&result, &tokens_iter);
    }
    
    _ = tokens_iter.next();
}

fn p_instr_cfg_label(result: *ParserResult, it: *iter.SliceIterator(ast.Token)) ParserError!void {
    const cur = it.next().?;
    switch (cur) {
        ast.TokenType.control => {
            if(cur.control == '.') {
                // Parse config
                const ident = try expect_token(it, ast.TokenType.identifier);
                if(std.mem.eql([]const u8, ident.identifier, "stack_size")) {
                    if(result.config.stack_size != 0) {
                        return ParserError.MultiConfig;
                    } else {
                        const val = try expect_token(it, ast.TokenType.number);
                        result.config.stack_size = val.number;
                    }
                } else if(std.mem.eql([]const u8, ident.identifier, "entry")) {
                    if(result.config.entry != 0) {
                        return ParserError.MultiConfig;
                    } else {
                        const val = try expect_token(it, ast.TokenType.identifier);
                        _ = val;
                    }
                } else {
                    it.next(); // Don't really care for an EOF if it is an unknown option.
                }
            } else {
                return ParserError.UnexpectedToken;
            }
        },
        ast.TokenType.identifier => {
            const ident = cur.identifier;
            if(matches_instruction(ident)) |instr_type| {
                _ = instr_type;
            } else {
                // Parse label
            }
        },
        else => return ParserError.UnexpectedToken,
    }
}

fn expect_token(it: *iter.SliceIterator(ast.Token), comptime expect: ast.TokenType) ParserError!ast.Token {
    const next = it.next();
    if(next) |ne| {
        if(ne == expect) {
            return next;
        } else {
            return ParserError.UnexpectedToken;
        }
    } else {
        return ParserError.UnexpectedEOF;
    }
}

fn expect_other_oken(it: *iter.SliceIterator(ast.Token), comptime expect: ast.TokenType) ParserError!ast.Token {
    const next = it.next();
    if(next) |ne| {
        if(ne == expect) {
            return ParserError.UnexpectedToken;
        } else {
            return next;
        }
    } else {
        return ParserError.UnexpectedEOF;
    }
}

const string_map = std.ComptimeStringMap(ast.ExprType, .{
    .{"add", ast.ExprType.add},
    .{"sub", ast.ExprType.sub},
    .{"mul", ast.ExprType.mul},
    .{"div", ast.ExprType.div},

    .{"b", ast.ExprType.b},
    .{"be", ast.ExprType.be},
    .{"bge", ast.ExprType.bge},
    .{"bg", ast.ExprType.bg},
    .{"ble", ast.ExprType.ble},
    .{"bl", ast.ExprType.bl},

    .{"cmp", ast.ExprType.cmp},
    .{"ret", ast.ExprType.ret},

    .{"res", ast.ExprType.res},
    .{"free", ast.ExprType.free},
    .{"str", ast.ExprType.str},
    .{"ldr", ast.ExprType.ldr},

    .{"print", ast.ExprType.print},
    .{"printa", ast.ExprType.printa},
});

fn matches_instruction(in: []const u8) ?ast.ExprType {
    return string_map.get(in);
}

fn parse_instr(result: *ParserResult, ty: ast.ExprType, it: *iter.SliceIterator(ast.Token)) ParserError!void {
    
}