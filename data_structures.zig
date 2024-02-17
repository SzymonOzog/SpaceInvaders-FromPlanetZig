const std = @import("std");
pub const PlayerInput = struct { left: bool, right: bool, shoot: bool };

pub const Sprite = struct {
    sizeX: u32,
    sizeY: u32,
    sheetX: u32,
    sheetY: u32,
    color: u32,
    mask: ?[]bool,
    currentAnim: u32 = 0,
    animations: u32 = 1,
    animX: u32 = 0,
    animY: u32 = 0,
    pub fn getCurrentSheetX(self: Sprite) u32 {
        return self.sheetX + self.currentAnim * self.animX;
    }
    pub fn getCurrentSheetY(self: Sprite) u32 {
        return self.sheetY + self.currentAnim * self.animY;
    }
};

pub const Object = struct {
    pos: Position,
    sprite: Sprite,
    index: usize = undefined,
    pub fn stepAnim(self: *Object, currentStep: u32) void {
        self.sprite.currentAnim = currentStep % self.sprite.animations;
    }
};

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
    pub fn init(pos: Position, sprite: *Sprite, allocator: std.mem.Allocator) !BunkerPart {
        const mask = try allocator.alloc(bool, sprite.sizeY * sprite.sizeX);
        sprite.mask = mask;
        @memset(mask, true);
        return BunkerPart{ .damage = 0, .obj = Object{ .pos = pos, .sprite = sprite.* } };
    }
    pub fn onHit(self: *BunkerPart) bool {
        var prng = std.rand.DefaultPrng.init(37);
        const rand = prng.random();
        self.*.damage += 1;
        var destroyed: u32 = 0;

        const size = self.obj.sprite.sizeX * self.obj.sprite.sizeY;
        var pixelIndex: u32 = 0;
        while (destroyed < size / self.maxDamage) {
            pixelIndex = (pixelIndex + 1) % size;
            if (rand.intRangeAtMost(u32, 0, self.maxDamage) == 1 and self.obj.sprite.mask.?[pixelIndex]) {
                self.obj.sprite.mask.?[pixelIndex] = false;
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
    pub fn init(pos: Position, sprite: Sprite, allocator: std.mem.Allocator) !Bunker {
        var ret = Bunker{ .parts = undefined };
        const stepX: u32 = sprite.sizeX / bW;
        const stepY: u32 = sprite.sizeY / bH;
        for (0..bH) |y| {
            for (0..bW) |x| {
                const i = y * bW + x;
                const offsetX: f32 = @floatFromInt(x * stepX);
                const offsetY: f32 = @floatFromInt(y * stepY);
                if (y == 0) {
                    if (x == 1 or x == 3) {
                        ret.parts[i] = null;
                    } else {
                        var partSprite = Sprite{ .sizeY = stepY, .sizeX = stepX * 2, .sheetX = sprite.sheetX + @as(u32, @intCast(x)) * stepX, .sheetY = sprite.sheetY + (bH - @as(u32, @intCast(y)) - 1) * stepY, .color = sprite.color, .mask = null };
                        ret.parts[i] = try BunkerPart.init(Position{ .x = pos.x + offsetX, .y = pos.y + offsetY }, &partSprite, allocator);
                    }
                } else {
                    var partSprite = Sprite{ .sizeY = stepY, .sizeX = stepX, .sheetX = sprite.sheetX + @as(u32, @intCast(x)) * stepX, .sheetY = sprite.sheetY + (bH - @as(u32, @intCast(y)) - 1) * stepY, .color = sprite.color, .mask = null };
                    ret.parts[i] = try BunkerPart.init(Position{ .x = pos.x + offsetX, .y = pos.y + offsetY }, &partSprite, allocator);
                }
            }
        }
        return ret;
    }
};
