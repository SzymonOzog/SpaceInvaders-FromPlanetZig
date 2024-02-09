pub const Color = struct { r: u8, g: u8, b: u8 };

pub const PlayerInput = struct { left: bool, right: bool, shoot: bool };

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

pub const Projectile = struct { pos: Position, dir: f32 };
