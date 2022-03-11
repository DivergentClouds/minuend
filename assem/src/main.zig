const std = @import("std");

const streql = std.ascii.eqlIgnoreCase;
var byte_num : u16 = 0;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var source = try std.fs.cwd().readFileAlloc(allocator, args[1], 0x100_0000); // 16 MiB
    defer allocator.free(source);

    var buf = try allocator.alloc(u8, 0x10000); // 64 KiB buffer
    defer allocator.free(buf);

    try assemble(source, buf);
    try std.fs.cwd().writeFile(args[2], buf[0..byte_num]);
}

fn assemble(source : []u8, buf : []u8) !void {
    var lines = std.mem.tokenize(u8, source, "\n");
    var line_number : u32 = 0;
    var byte : u8 = undefined;
    var reg : u8 = undefined;

    while (lines.next()) |line| {
        line_number +=1;
        var line_len : usize = (std.mem.indexOf(u8, line, ";") orelse line.len);

        var tokens = std.mem.tokenize(u8, line[0..line_len], std.ascii.spaces[0..]);

        if (tokens.next()) |token| {

            if (streql(token, ".bbyte")) {
                while (tokens.next()) |token_num| {
                    byte = try std.fmt.parseInt(u8, token_num, 2);
                    extendBuf(buf, byte);
                }
            } else if(streql(token, ".obyte")) {
                while (tokens.next()) |token_num| {
                    byte = try std.fmt.parseInt(u8, token_num, 8);
                    extendBuf(buf, byte);
                }
            } else if (streql(token, ".dbyte")) {
                while (tokens.next()) |token_num| {
                    byte = try std.fmt.parseInt(u8, token_num, 10);
                    extendBuf(buf, byte);
                }
            } else if (streql(token, ".xbyte")) {
                while (tokens.next()) |token_num| {
                    byte = try std.fmt.parseInt(u8, token_num, 16);
                    extendBuf(buf, byte);
                }
            } else {
                if (streql(token, "sub")) {
                    byte = 0;
                } else if (streql(token, "subr")) {
                    byte = (0b01 << 6);
                } else if (streql(token, "leq")) {
                    byte = (0b10 << 6);
                } else if (streql(token, "leqr")) {
                    byte = (0b11 << 6);
                }

                if (tokens.next()) |token_arg| {
                    reg = regId(token_arg) catch |err|{
                            std.log.err("Line {d}: {s} at {s}", .{line_number, @errorName(err), token_arg});
                            return err;
                    };
                    byte += reg << 3;
                }

                if (tokens.next()) |token_arg| {
                    reg = regId(token_arg) catch |err|{
                            std.log.err("Line {d}: {s} at {s}", .{line_number, @errorName(err), token_arg});
                            return err;
                    };
                    byte += reg;
                }

                if (tokens.next()) |token_extra| {
                    std.log.err("Line {d}: too many arguments at {s}", .{line_number, token_extra});
                    return error.tooManyTokens;
                }

                extendBuf(buf, byte);
            }
        }
    }
}

fn regId(name : []const u8) !u3 {
    if (streql(name, "r0")) {
        return 0;
    } else if (streql(name, "r1")) {
        return 1;
    } else if (streql(name, "r2")) {
        return 2;
    } else if (streql(name, "pc") or streql(name, "r3")) {
        return 3;
    } else if (streql(name, "(r0)")) {
        return 4;
    } else if (streql(name, "(r1)")) {
        return 5;
    } else if (streql(name, "(r2)")) {
        return 6;
    } else if (streql(name, "(pc)") or streql(name, "(r3)")) {
        return 7;
    } else {
        return error.badRegisterName;
    }
}

fn extendBuf(buf : []u8, value : u8) void {
    buf[byte_num] = value;
    byte_num += 1;
}
