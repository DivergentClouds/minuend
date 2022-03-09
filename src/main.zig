const std = @import("std");
const fs = std.fs;
const writer = std.io.getStdOut().writer();

const clock_speed = 500; // 2Mhz
const memory_size = 0x10000; // number of values a 16-bit integer can hold

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var memory = try allocator.alloc(u8, memory_size);
    _ = try fs.cwd().readFile(args[1], memory);

    defer allocator.free(memory);

    // registers, 4th register is pc
    var r: [4]u16 = .{undefined, undefined, undefined, 0};

    var running : bool = true;

    while (running) {
        running = try cycle(&r, memory);
        std.time.sleep(clock_speed);
    }

//    std.debug.print("registers: {o}, {o}, {o}, {o}\n", .{r[0], r[1], r[2], r[3]});
}

fn cycle(r : *[4]u16, mem : []u8) !bool {
    var loc = mem[r[3]];
    var do_src_deref : bool = undefined;
    var do_dest_deref : bool = undefined;
    var src_reg : u2 = undefined;
    var dest_reg : u2 = undefined;
    var hold : u16 = undefined;
    var s_hold : i16 = undefined;

    r[3] +|= 1;

    // bit patterns for decoding
    const op_bits : u8 = 0b1000_0000;
    const reverse_bits : u8 = 0b0100_0000;
    const src_deref_bits : u8 = 0b0010_0000;
    const src_bits : u8 = 0b0001_1000;
    const dest_deref_bits : u8 = 0b0000_0100;
    const dest_bits : u8 = 0b0000_0011;

    src_reg = @truncate(u2, (loc & src_bits) >> 3);
    dest_reg = @truncate(u2, loc & dest_bits);

    do_src_deref = (loc & src_deref_bits == src_deref_bits);
    do_dest_deref = (loc & dest_deref_bits == dest_deref_bits);
    
    var src : u16 = try load(do_src_deref, src_reg, r, mem);
    var dest : u16 = try load(do_dest_deref, dest_reg, r, mem);

    if (loc & op_bits == 0) { // Sub
        if (loc & reverse_bits == 0) { // Sub
            hold = dest -% src;
        } else { // SubR
            hold = @bitReverse(u16, @bitReverse(u16, dest) -% @bitReverse(u16, src));
        }

        try store(do_dest_deref, hold, dest_reg, r, mem);
    } else { // Leq
        if (loc & reverse_bits == 0) { // Leq
            s_hold = @bitCast(i16, src);
        } else { // LeqR
            s_hold = @bitReverse(i16, @bitCast(i16, src));
        }

        if (s_hold <= 0) {
            r[3] = dest;
        }

        if (r[3] >= 0xfffe) {
            return false;
        }
    }

    return true;
}

fn load(do_deref : bool, reg : u2, r : *[4]u16, mem : []u8) !u16 {
    var temp : u16 = undefined;

    if (do_deref) {
        if (r[reg] == 0xffff) {
            temp = 0;
        } else if (r[reg] == 0xfffe) {
            temp = try std.io.getStdIn().reader().readByte();
        } else {
            //std.debug.print("{x}\n", .{mem[r[reg]]});
            temp = @intCast(u16, mem[r[reg]]) + (@intCast(u16, mem[r[reg] + 1]) << 8);
            }
        if (reg == 3) r[reg] +%= 2; // number of bytes loaded
        return temp;
    } else {
        return r[reg];
    }
}

fn store(do_deref : bool, value : u16, reg : u2, r : *[4]u16, mem : []u8) !void {
    if (do_deref) {
        if (r[reg] == 0xffff) {
            try writer.writeByte(@truncate(u8, std.mem.nativeToLittle(u16, value))); // write LSB to stdout
        } else {
            mem[r[reg]] = @truncate(u8, value);
            mem[r[reg] + 1] = @truncate(u8, value >> 8);
        }
        if (reg == 3) r[reg] +%= 2; // number of bytes loaded

    } else {
        r[reg] = value;
    }
}
