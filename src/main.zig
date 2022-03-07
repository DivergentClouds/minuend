const std = @import("std");
const fs = std.fs;

const clock_speed = 500; // 2Mhz
const memory_size = 65536; // number of values a 16-bit integer can hold

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var memory = try fs.cwd().readFileAlloc(allocator, args[1], memory_size);
    defer allocator.free(memory);
    
    // 4th register is pc
    var registers : [4]u16 = .{undefined, undefined, undefined, 0};

    while (true) {
        cycle(&registers, memory);
        std.time.sleep(clock_speed);
    }
}

fn cycle(reg : *[4]u16, mem : []u8) void {
    var r : [4]u16 = reg.*;
    var loc = mem[r[3]];
    var do_src_deref : bool = undefined;
    var do_dest_deref : bool = undefined;
    var src_reg : u2 = undefined;
    var dest_reg : u2 = undefined;
    var hold : u16 = undefined;
    var s_hold : i16 = undefined;

    r[3] +%= 1;

    // bit patterns for decoding
    const op_bits : u8 = 0b1000_0000;
    const reverse_bits : u8 = 0b0100_0000;
    const src_deref_bits : u8 = 0b0010_0000;
    const src_bits : u8 = 0b0001_1000;
    const dest_deref_bits : u8 = 0b0000_0100;
    const dest_bits : u8 = 0b0000_0011;

    src_reg = @truncate(u2, (loc & src_bits) >> 3);
    dest_reg = @truncate(u2, loc & dest_bits);

    do_src_deref = (loc & src_deref_bits == 1);
    do_dest_deref = (loc & dest_deref_bits == 1);
    
    var src : u16 = load(do_src_deref, src_reg, r, mem);
    var dest : u16 = load(do_dest_deref, dest_reg, r, mem);

    if (loc & op_bits == 0) { // Sub
        if (loc & reverse_bits == 0) { // Sub
            hold = dest - src;
        } else { // SubR
            hold = @bitReverse(u16, @bitReverse(u16, dest) - @bitReverse(u16, src));
        }

        store(do_dest_deref, hold, dest_reg, &r, mem);
    } else { // Leq
        if (loc & reverse_bits == 0) { // Leq
            s_hold = @bitCast(i16, src);
        } else { // LeqR
            s_hold = @bitReverse(i16, @bitCast(i16, src));
        }

        if (hold <= 0) {
            r[3] = dest;
        }
    }
}

fn load(do_deref : bool, reg : u2, r : [4]u16, mem : []u8) u16 {
    if (do_deref) {
        return mem[r[reg]] + (mem[r[reg + 1] << 8]);
    } else {
        return r[reg];
    }
}

fn store(do_deref : bool, value : u16, reg : u2, registers : *[4]u16, mem : []u8) void {
    var r : [4]u16 = registers.*;

    if (do_deref) {
        mem[r[reg]] = @truncate(u8, value);
        mem[r[reg] + 1] = @truncate(u8, value >> 8);
    } else {
        r[reg] = value;
    }
}
