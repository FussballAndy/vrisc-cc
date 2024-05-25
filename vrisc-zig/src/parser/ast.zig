const instructions = @import("./instructions.zig");

pub const TokenType = enum {
    identifier,
    control,
    number
};

pub const Token = union(TokenType) {
    identifier: []const u8,
    control: u8,
    number: usize,
};

pub const ExprType = enum {
    add,
    sub,
    mul,
    div,

    b, be, bge, bg, ble, bl,
    cmp,
    ret,

    mov,
    res,
    free,
    str,
    ldr,

    print,
    printa
};

pub const Expr = union(ExprType) {
    add: instructions.Arithmetic,
    sub: instructions.Arithmetic,
    mul: instructions.Arithmetic,
    div: instructions.Arithmetic,

    b: instructions.Branching,
    be: instructions.Branching,
    bge: instructions.Branching,
    bg: instructions.Branching,
    ble: instructions.Branching,
    bl: instructions.Branching,
    cmp: instructions.Compare,
    ret: void,

    mov: instructions.Memory,

    res: instructions.RegOrConst,
    free: instructions.RegOrConst,

    str: instructions.Memory,
    ldr: instructions.Memory,

    print: u4,
    printa: u4,
};