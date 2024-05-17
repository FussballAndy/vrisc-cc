const std = @import("std");
const lexer = @import("./lexer.zig");
const parser = @import("./parser.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        std.log.err("Usage: vsric <file>", .{});
        return;
    }

    const file_name = args[1];

    const cwd = std.fs.cwd();

    const file_handle = cwd.openFile(file_name, .{}) catch |err| {
        switch (err) {
            error.FileNotFound => std.log.err("File {s} was not found", .{file_name}),
            else => |err_o| std.log.err("{!}", .{err_o})
        }

        return;
    };

    defer file_handle.close();

    const content = try file_handle.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(content);

    const tokens = try lexer.parse_tokens(content);

    try parser.parse_expr(tokens);

    allocator.free(tokens);

    std.log.debug("Read file starting parser", .{});
}