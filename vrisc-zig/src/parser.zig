const lexer = @import("./parser/lexer.zig");
const parser = @import("./parser/parser.zig");
pub const ast = @import("./parser/ast.zig");
pub const instr = @import("./parser/instructions.zig");

pub const parseTokens = lexer.parseTokens;
pub const parseExpr = parser.parseExpr;
pub const ParserResult = parser.ParserResult;
pub const RuntimeConfig = parser.RuntimeConfig;