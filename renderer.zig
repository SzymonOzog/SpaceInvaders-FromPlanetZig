const std = @import("std");
const ds = @import("data_structures.zig");

var W: u32 = undefined;
var H: u32 = undefined;
const backgroundColor = 0;
pub var buffer: []u32 = undefined;

var spriteMap: std.StringHashMap(ds.Sprite) = undefined;
var spriteSheet: []bool = undefined;
var spriteSheetW: u32 = undefined;

pub fn clearBuffer() void {
    for (0..buffer.len) |i| {
        buffer[i] = backgroundColor;
    }
}

pub fn setPixel(x: u32, y: u32, color: u32) void {
    if (color < 0x01000000) {
        buffer[(W * y) + x] = color;
    }
}

pub fn drawSprite(x: u32, y: u32, sprite: ds.Sprite) void {
    for (0..sprite.sizeY) |i| {
        for (0..sprite.sizeX) |j| {
            if (y + i < H and x + j < W and spriteSheet[((sprite.getCurrentSheetY() + sprite.sizeY - i) * spriteSheetW + sprite.getCurrentSheetX() + j)]) {
                if (sprite.mask) |m| {
                    if (m[i * sprite.sizeX + j]) {
                        setPixel(@intCast(x + j), @intCast(y + i), sprite.color);
                    }
                } else {
                    setPixel(@intCast(x + j), @intCast(y + i), sprite.color);
                }
            }
        }
    }
}

pub fn init(width: u32, height: u32, inSpriteMap: std.StringHashMap(ds.Sprite), inSpriteSheet: []bool, inSpriteSheetW: u32, allocator: std.mem.Allocator) !void {
    const buf = try allocator.alloc(u32, width * height);
    @memset(buf, backgroundColor);
    W = width;
    H = height;
    buffer = buf;
    spriteSheet = inSpriteSheet;
    spriteMap = inSpriteMap;
    spriteSheetW = inSpriteSheetW;
}
