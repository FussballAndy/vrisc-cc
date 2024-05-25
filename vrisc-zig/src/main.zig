const std = @import("std");
const parser = @import("./parser.zig");
const runtime = @import("./runtime.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        std.log.err("Usage: vsric <file>", .{});
        return;
    }

    const file_name = args[1];
    var parser_reult = try readAndParseFile(file_name, allocator);

    defer parser_reult.deinit();
}

fn readAndParseFile(file_name: []const u8, allocator: std.mem.Allocator) !parser.ParserResult {

    const cwd = std.fs.cwd();

    const file_handle = cwd.openFile(file_name, .{}) catch |err| {
        if(err == std.fs.File.OpenError.FileNotFound) {
            std.log.err("File {s} was not found", .{file_name});
        }

        return err;
    };

    defer file_handle.close();

    const content = try file_handle.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(content);

    const tokens = try parser.parseTokens(content);

    return parser.parseExpr(tokens);
}