const std = @import("std");
const parser = @import("./parser.zig");

pub const RuntimeCreationError = error {
    UndefinedEntry
} || std.mem.Allocator.Error;

pub const Runtime = struct {
    stack_size: u64,
    entry: u64,
    instrs: []const parser.ast.Expr,
    labels: []const ?u64,

    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.labels);
        self.allocator.free(self.instrs);
    }
};

pub fn createRuntime(parser_result: *parser.ParserResult, allocator: std.mem.Allocator) RuntimeCreationError!Runtime {
    const stack_size: u64 = if(parser_result.config.stack_size != 0) 
        parser_result.config.stack_size
    else
        4096;
    const entry: u64 = if(parser_result.config.entry) |entry_idx_smol| 
        parser_result.config.label_counters.items[@as(usize, entry_idx_smol)] orelse return RuntimeCreationError.UndefinedEntry
    else
        0;
    const instrs = try parser_result.instrs.toOwnedSlice();
    const labels = try parser_result.config.label_counters.toOwnedSlice();

    return Runtime{
        .stack_size = stack_size,
        .entry = entry,
        .instrs = instrs,
        .labels = labels,

        .allocator = allocator,
    };
}

pub const RuntimeError = error {
    UndefinedLabel,
    LabelAtEnd,
    DivByZero,
    NegativeOperation,
    StackOverflow,
    StackUnderflow,
    InvalidUTF8
} || std.mem.Allocator.Error || std.io.AnyWriter.Error;

pub fn executeRuntime(runtime: Runtime) RuntimeError!void {
    const allocator = runtime.allocator;
    const stdout_file = std.io.getStdOut();
    const stdout_writer = stdout_file.writer();
    var stdout_buf = std.io.bufferedWriter(stdout_writer);
    const stdout = stdout_buf.writer();

    var graceful = false;
    var pc = runtime.entry;

    var stack = try allocator.alloc(i64, runtime.stack_size);
    var stack_pointer: u64 = 0;
    defer allocator.free(stack);

    var registers = std.mem.zeroes([16]i64);
    var cmp_reg: i8 = 0;

    const len = runtime.instrs.len;

    try stdout.print("\n=== Start of Program ===\n", .{});
    try stdout_buf.flush();

    loop: while (pc < len) {
        const cur = runtime.instrs[pc];
        switch (cur) {
            .add => |arithm| {
                const first = getValueOfRegOrConst(arithm.first, &registers);
                const second = getValueOfRegOrConst(arithm.second, &registers);
                registers[arithm.goal] = first + second;
            },
            .sub => |arithm| {
                const first = getValueOfRegOrConst(arithm.first, &registers);
                const second = getValueOfRegOrConst(arithm.second, &registers);
                registers[arithm.goal] = first - second;
            },
            .mul => |arithm| {
                const first = getValueOfRegOrConst(arithm.first, &registers);
                const second = getValueOfRegOrConst(arithm.second, &registers);
                registers[arithm.goal] = first * second;
            },
            .div => |arithm| {
                const first = getValueOfRegOrConst(arithm.first, &registers);
                const second = getValueOfRegOrConst(arithm.second, &registers);
                if(second == 0) {
                    return RuntimeError.DivByZero;
                }
                registers[arithm.goal] = @divFloor(first, second);
            },

            .b => |branch| {
                pc = branch.counter;
            },
            .bg => |branch| {
                if(cmp_reg > 0) {
                    pc = branch.counter;
                }
            },
            .bl => |branch| {
                if(cmp_reg < 0) {
                    pc = branch.counter;
                }
            },
            .bge => |branch| {
                if(cmp_reg >= 0) {
                    pc = branch.counter;
                }
            },
            .ble => |branch| {
                if(cmp_reg <= 0) {
                    pc = branch.counter;
                }
            },
            .be => |branch| {
                if(cmp_reg == 0) {
                    pc = branch.counter;
                }
            },

            .cmp => |cmp| {
                const left = registers[cmp.left];
                const right = getValueOfRegOrConst(cmp.right, &registers);
                cmp_reg = if(left < right) 
                    -1
                else if(left > right)
                    1
                else
                    0;
            },
            .ret => {
                graceful = true;
                break :loop;
            },


            .mov => |mem| {
                const val = getValueOfRegOrConst(mem.address, &registers);
                registers[mem.source] = val;
            },
            .res => |roc| {
                const val = getValueOfRegOrConst(roc, &registers);
                if(val < 0) {
                    return RuntimeError.NegativeOperation;
                }
                const uval: u64 = @intCast(val);
                stack_pointer += uval;
                if(stack_pointer >= stack.len) {
                    return RuntimeError.StackOverflow;
                }
            },
            .free => |roc| {
                const val = getValueOfRegOrConst(roc, &registers);
                if(val < 0) {
                    return RuntimeError.NegativeOperation;
                }
                const uval: u64 = @intCast(val);
                if(uval > stack_pointer) {
                    return RuntimeError.StackUnderflow;
                }
                stack_pointer -= uval;
            },
            .str => |mem| {
                const address = getValueOfRegOrConst(mem.address, &registers);
                if(address < 0) {
                    return RuntimeError.NegativeOperation;
                }
                const val = registers[mem.source];
                stack[@intCast(address)] = val;
            },
            .ldr => |mem| {
                const address = getValueOfRegOrConst(mem.address, &registers);
                if(address < 0) {
                    return RuntimeError.NegativeOperation;
                }
                const val = stack[@intCast(address)];
                registers[mem.source] = val;
            },

            .print => |reg| {
                const val = registers[reg];
                try stdout.print("{d}", .{val});
                try stdout_buf.flush();
            },
            .printa => |reg| {
                const val = registers[reg];
                if(val < comptime std.math.pow(i64, 2, 21)) {
                    const smoll: u21 = @intCast(val);
                    if(!std.unicode.utf8ValidCodepoint(smoll)) {
                        return RuntimeError.InvalidUTF8;
                    }
                    try stdout.print("{u}", .{smoll});
                    try stdout_buf.flush();
                } else {
                    return RuntimeError.InvalidUTF8;
                }
            }
        }
        pc+=1;
    }

    try stdout.writeAll("\n\n");
    try stdout_buf.flush();
    
    if(!graceful) {
        try stdout.print("Warning: End of instructions reached, program didn't end gracefully. If you wish you properly exit the program put a 'ret' instruction at the end!\n", .{});
        try stdout_buf.flush();
    }
    

}

fn getValueOfRegOrConst(item: parser.instr.RegOrConst, regs: *[16]i64) i64 {
    return switch (item) {
        .con => |val| @intCast(val),
        .reg => |reg| regs[reg]
    };
}