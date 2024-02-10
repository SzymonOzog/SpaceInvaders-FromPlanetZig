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
