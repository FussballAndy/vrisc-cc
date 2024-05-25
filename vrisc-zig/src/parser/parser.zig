const std = @import("std");
const ast = @import("./ast.zig");
const instr = @import("./instructions.zig");
const iter = @import("../iterator.zig");

pub const RuntimeConfig = struct {
    stack_size: u64 = 0,
    entry: u32 = 0,
    label_counters: std.ArrayList(?u64),
};

pub const ParserResult = struct {
    instrs: std.ArrayList(ast.Expr),
    config: RuntimeConfig,
    label_map: std.StringHashMap(u32),

    const Self = @This();
    pub fn deinit(self: *Self) void {
        self.instrs.deinit();
        self.config.label_counters.deinit();
        self.label_map.deinit();
    }
};

const ParserError = error{
    UnexpectedToken,
    UnexpectedEOF,
    MultiConfig,
    NotARegister,
} || std.mem.Allocator.Error;

const ParserIterator = iter.SliceIterator(ast.Token);

pub fn parseExpr(tokens: []ast.Token) ParserError!ParserResult {
    var result: ParserResult = .{
        .instrs = std.ArrayList(ast.Expr).init(std.heap.page_allocator),
        .config = .{ .label_counters = std.ArrayList(?u64).init(std.heap.page_allocator) },
        .label_map = std.StringHashMap(u32).init(std.heap.page_allocator),
    };

    // Won't be needed after parsing, in theory parserresult could also have a successor struct
    defer result.label_map.deinit();

    var tokens_iter = ParserIterator{ .inner = tokens };

    while (tokens_iter.hasNext()) {
        try parseTopLevel(&result, &tokens_iter);
    }

    return result;
}

// Parse Instruction, Config or label
fn parseTopLevel(result: *ParserResult, it: *ParserIterator) ParserError!void {
    const cur = it.next().?;
    switch (cur) {
        ast.TokenType.control => {
            if (cur.control == '.') {
                // Parse config
                const ident = try expectToken(it, ast.TokenType.identifier);
                if (std.mem.eql(u8, ident.identifier, "stack_size")) {
                    if (result.config.stack_size != 0) {
                        std.log.err("Config 'stack_size'", .{});
                        return ParserError.MultiConfig;
                    } else {
                        const val = try expectToken(it, ast.TokenType.number);
                        result.config.stack_size = val.number;
                    }
                } else if (std.mem.eql(u8, ident.identifier, "entry")) {
                    if (result.config.entry != 0) {
                        std.log.err("Config 'entry' already assigned", .{});
                        return ParserError.MultiConfig;
                    } else {
                        const val = try expectToken(it, ast.TokenType.identifier);
                        result.config.entry = try getOrCreateLabel(result, val.identifier, null);
                    }
                } else {
                    _ = it.next(); // Don't really care for an EOF if it is an unknown option.
                }
            } else {
                return ParserError.UnexpectedToken;
            }
        },
        ast.TokenType.identifier => {
            const ident = cur.identifier;
            if (matchInstruction(ident)) |instr_type| {
                try parseInstruction(result, instr_type, it);
            } else {
                const colon = try expectToken(it, ast.TokenType.control);
                if (colon.control == ':') {
                    const label = colon.identifier;
                    _ = try getOrCreateLabel(result, label, result.instrs.items.len);
                } else {
                    return ParserError.UnexpectedToken;
                }
            }
        },
        else => return ParserError.UnexpectedToken,
    }
}

fn expectToken(it: *ParserIterator, comptime expect: ast.TokenType) ParserError!ast.Token {
    const next = it.next() orelse return ParserError.UnexpectedEOF;
    if (next == expect) {
        return next;
    } else {
        return ParserError.UnexpectedToken;
    }
}

const string_map = std.ComptimeStringMap(ast.ExprType, .{
    .{ "add", ast.ExprType.add },
    .{ "sub", ast.ExprType.sub },
    .{ "mul", ast.ExprType.mul },
    .{ "div", ast.ExprType.div },

    .{ "b", ast.ExprType.b },
    .{ "be", ast.ExprType.be },
    .{ "bge", ast.ExprType.bge },
    .{ "bg", ast.ExprType.bg },
    .{ "ble", ast.ExprType.ble },
    .{ "bl", ast.ExprType.bl },

    .{ "cmp", ast.ExprType.cmp },
    .{ "ret", ast.ExprType.ret },

    .{ "mov", ast.ExprType.mov },
    .{ "res", ast.ExprType.res },
    .{ "free", ast.ExprType.free },
    .{ "str", ast.ExprType.str },
    .{ "ldr", ast.ExprType.ldr },

    .{ "print", ast.ExprType.print },
    .{ "printa", ast.ExprType.printa },
});

fn matchInstruction(in: []const u8) ?ast.ExprType {
    return string_map.get(in);
}

fn parseInstruction(result: *ParserResult, ty: ast.ExprType, it: *ParserIterator) ParserError!void {
    const instruction: ast.Expr = switch (ty) {
        .add => .{ .add = try parseArithmeticInstruction(it) },
        .sub => .{ .sub = try parseArithmeticInstruction(it) },
        .mul => .{ .mul = try parseArithmeticInstruction(it) },
        .div => .{ .div = try parseArithmeticInstruction(it) },

        .b => .{ .b = try parseBranching(result, it) },
        .be => .{ .be = try parseBranching(result, it) },
        .bg => .{ .bg = try parseBranching(result, it) },
        .bge => .{ .bge = try parseBranching(result, it) },
        .bl => .{ .bl = try parseBranching(result, it) },
        .ble => .{ .ble = try parseBranching(result, it) },

        .cmp => .{ .cmp = try parseCompare(it) },

        .ret => .{ .ret = {} },

        .mov => .{ .mov = try parseMemory(it) },

        .res => .{ .res = try parseRegOrConst(it) },
        .free => .{ .free = try parseRegOrConst(it) },

        .str => .{ .str = try parseMemory(it) },
        .ldr => .{ .ldr = try parseMemory(it) },

        .print => .{ .print = try parseRegister(it) },
        .printa => .{ .printa = try parseRegister(it) },
    };
    try result.instrs.append(instruction);
}

fn parseArithmeticInstruction(it: *ParserIterator) ParserError!instr.Arithmetic {
    const goal = try parseRegister(it);
    try parseControl(it, ',');
    const first = try parseRegOrConst(it);
    try parseControl(it, ',');
    const second = try parseRegOrConst(it);
    return .{ .goal = goal, .first = first, .second = second };
}

fn parseRegOrConst(it: *ParserIterator) ParserError!instr.RegOrConst {
    const token = it.next() orelse return ParserError.UnexpectedEOF;
    return switch (token) {
        .identifier => |idt| .{ .reg = try parseRegisterRaw(idt) },
        .number => |num| .{ .con = num },
        else => return ParserError.UnexpectedToken,
    };
}

fn parseRegisterRaw(ident: []const u8) ParserError!u4 {
    if (ident.len >= 2 and ident.len <= 3) {
        return ParserError.NotARegister;
    }
    if (ident[0] != 'r') {
        return ParserError.NotARegister;
    }
    const reg_num = std.fmt.parseInt(u4, ident[1..], 10) catch {
        return ParserError.NotARegister;
    };
    return reg_num;
}

fn parseRegister(it: *ParserIterator) ParserError!u4 {
    const reg_token = try expectToken(it, ast.TokenType.identifier);
    return try parseRegisterRaw(reg_token.identifier);
}

fn parseControl(it: *ParserIterator, comptime control: u8) ParserError!void {
    const token = try expectToken(it, ast.TokenType.control);
    if (token.control != control) {
        return ParserError.UnexpectedToken;
    }
}

fn parseBranching(result: *ParserResult, it: *ParserIterator) ParserError!instr.Branching {
    const label_token = try expectToken(it, ast.TokenType.identifier);
    const label_ident = label_token.identifier;
    return .{ .counter = try getOrCreateLabel(result, label_ident, null) };
}

fn parseCompare(it: *ParserIterator) ParserError!instr.Compare {
    const left_reg = try parseRegister(it);
    try parseControl(it, ',');
    const right = try parseRegOrConst(it);
    return .{ .left = left_reg, .right = right };
}

fn parseMemory(it: *ParserIterator) ParserError!instr.Memory {
    const source = try parseRegister(it);
    try parseControl(it, ',');
    const address = try parseRegOrConst(it);
    return .{ .source = source, .address = address };
}

fn getOrCreateLabel(result: *ParserResult, ident: []const u8, val: ?u64) ParserError!u32 {
    if (result.label_map.get(ident)) |label_idx| {
        return label_idx;
    } else {
        const lbl_idx = result.label_map.count();
        try result.label_map.put(ident, lbl_idx);
        try result.config.label_counters.ensureTotalCapacity(@as(usize, lbl_idx));
        result.config.label_counters.items[lbl_idx] = val;
        return lbl_idx;
    }
}
