const std = @import("std");
pub const PlayerInput = struct { left: bool, right: bool, shoot: bool };

pub const Sprite = struct {
    sizeX: u32,
    sizeY: u32,
    pixels: [*]u32,
    pub fn getPixel(self: Sprite, x: u32, y: u32) u32 {
        return self.pixels[y * self.sizeX + x];
    }
};

pub const Object = struct { pos: Position, sprite: Sprite };

pub const Position = struct {
    x: f32,
    y: f32,

    pub fn roundX(self: Position) u32 {
        return @intFromFloat(self.x);
    }

    pub fn roundY(self: Position) u32 {
        return @intFromFloat(self.y);
    }
};

pub const Projectile = struct { obj: Object, dir: f32 };
pub const DeathMarker = struct { obj: Object, lifetime: i64, creationTime: i64 };
pub const BunkerPart = struct {
    obj: Object,
    damage: u32,
    maxDamage: u32 = 4,
    pixels: []u32,
    pub fn init(pos: Position, sizeX: u32, sizeY: u32, pixels: []u32, allocator: std.mem.Allocator) !BunkerPart {
        const ptr = try allocator.alloc(u32, sizeY * sizeX);
        std.debug.print("created \n ", .{});
        @memcpy(ptr, pixels);
        return BunkerPart{ .damage = 0, .pixels = ptr, .obj = Object{ .pos = pos, .sprite = Sprite{ .sizeX = sizeX, .sizeY = sizeY, .pixels = ptr.ptr } } };
    }
    pub fn onHit(self: *BunkerPart) bool {
        var prng = std.rand.DefaultPrng.init(37);
        const rand = prng.random();
        self.*.damage += 1;
        std.debug.print("part hit damage {d}", .{self.*.damage});
        var destroyed: u32 = 0;

        const size = self.obj.sprite.sizeX * self.obj.sprite.sizeY;
        var pixelIndex: u32 = 0;
        while (destroyed < size / self.maxDamage) {
            pixelIndex = (pixelIndex + 1) % size;
            if (rand.intRangeAtMost(u32, 0, self.maxDamage) == 1 and self.pixels[pixelIndex] < 0x1000000) {
                self.pixels[pixelIndex] = 0xFF000000;
                destroyed += 1;
            }
        }
        return self.*.damage >= self.*.maxDamage;
    }
};
const bW = 4;
const bH = 3;
pub const Bunker = struct {
    parts: [bW * bH]?BunkerPart,
    pub fn init(pos: Position, sizeX: u32, sizeY: u32, pixels: [bW * bH][]u32, allocator: std.mem.Allocator) !Bunker {
        var ret = Bunker{ .parts = undefined };
        for (0..bH) |y| {
            for (0..bW) |x| {
                const i = y * bW + x;
                const offsetX: f32 = @floatFromInt(x * sizeX);
                const offsetY: f32 = @floatFromInt(y * sizeY);
                if (y == 0 and (x == 1 or x == 2)) {
                    ret.parts[i] = null;
                } else {
                    ret.parts[i] = try BunkerPart.init(Position{ .x = pos.x + offsetX, .y = pos.y + offsetY }, sizeX, sizeY, pixels[i], allocator);
                }
            }
        }
        return ret;
    }
};
