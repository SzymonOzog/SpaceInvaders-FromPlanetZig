const std = @import("std");
const windows = std.os.windows;
const kernel32 = windows.kernel32;
const ds = @import("data_structures.zig");
const w = @import("windows_window.zig");

const COORD = windows.COORD;
const DWORD = windows.DWORD;
const HANDLE = windows.HANDLE;

pub fn clearConsole() !void {
    var csbi: windows.CONSOLE_SCREEN_BUFFER_INFO = undefined;
    std.debug.print("\nterm size {d}, {d}!\n", .{ csbi.dwSize.X, csbi.dwSize.Y });
    const optional_stdoutHandle: ?HANDLE = kernel32.GetStdHandle(windows.STD_OUTPUT_HANDLE);
    if (optional_stdoutHandle) |stdoutHandle| {
        if (kernel32.GetConsoleScreenBufferInfo(stdoutHandle, &csbi) == 0) {
            std.debug.print("Error", .{});
        }
        const tl: COORD = .{ .X = 0, .Y = 0 };
        var written: DWORD = undefined;
        std.debug.print("\nterm size {d}, {d}!\n", .{ csbi.dwSize.X, csbi.dwSize.Y });
        const consoleX: u32 = @intCast(csbi.dwSize.X);
        const consoleY: u32 = @intCast(csbi.dwSize.Y);
        const cells = consoleX * consoleY;

        if (kernel32.FillConsoleOutputCharacterA(stdoutHandle, ' ', cells, tl, &written) == 0) {
            std.debug.print("Error at FillConsoleOutputCharacterA", .{});
        } else if (kernel32.FillConsoleOutputAttribute(stdoutHandle, csbi.wAttributes, cells, tl, &written) == 0) {
            std.debug.print("Error at FillConsoleOutputAttribute", .{});
        } else if (kernel32.SetConsoleCursorPosition(stdoutHandle, tl) == 0) {
            std.debug.print("Error at SetConsoleCursorPosition", .{});
        }
    }
}

const blockSize = 30;
const blockOffset = 5;
const pointsByRow: [5]u32 = .{ 30, 20, 20, 10, 10 };

const W: u32 = 800;
const H: u32 = 600;
const backgroundColor = 0xFF;
var buffer: [W * H]u32 = [1]u32{backgroundColor} ** (W * H);

var playerSprite: [blockSize * blockSize]u32 = .{0xFF00} ** (blockSize * blockSize);
var enemySprite1: [blockSize * blockSize]u32 = .{0xFF0000} ** (blockSize * blockSize);
var enemySprite2: [blockSize * blockSize]u32 = .{0xAFFF00} ** (blockSize * blockSize);
var enemySprite3: [blockSize * blockSize]u32 = .{0xEFFF00} ** (blockSize * blockSize);
var enemyDeathSprite: [blockSize * blockSize]u32 = .{0xFFFFFF} ** (blockSize * blockSize);
var projectileSprite: [blockSize * 10]u32 = .{0xFFFFFF} ** (10 * blockSize);

var playerInput = ds.PlayerInput{ .left = false, .right = false, .shoot = false };

var player = ds.Object{ .pos = ds.Position{ .x = 0, .y = 100 }, .sprite = ds.Sprite{ .sizeX = blockSize, .sizeY = blockSize, .pixels = &playerSprite } };
var points: u32 = 0;

var enemies: [5][11]?ds.Object = .{.{null} ** 11} ** 5;
var deathMarkers: [100]?ds.DeathMarker = .{null} ** 100;
var enemyStartPos = ds.Position{ .x = 10, .y = 400 };

pub fn createEnemies() void {
    for (enemies, 0..) |row, y| {
        for (row, 0..) |_, x| {
            const offsetX: f32 = @floatFromInt(x * (blockSize + blockOffset));
            const offsetY: f32 = @floatFromInt(y * (blockSize + blockOffset));
            const pos = ds.Position{ .x = enemyStartPos.x + offsetX, .y = enemyStartPos.y - offsetY };
            var pixels: [*]u32 = undefined;
            if (y < 1) {
                pixels = &enemySprite1;
            } else if (y < 3) {
                pixels = &enemySprite2;
            } else {
                pixels = &enemySprite3;
            }
            enemies[y][x] = ds.Object{ .pos = pos, .sprite = ds.Sprite{ .sizeX = blockSize, .sizeY = blockSize, .pixels = pixels } };
        }
    }
}

const projectileSpeed: f32 = 0.001;
const projectileSpawnDistance: f32 = blockSize;
const shootCooldownMicro = 1e6;

var projectiles: [100]?ds.Projectile = .{null} ** 100;

pub fn clearBuffer() void {
    for (0..buffer.len) |i| {
        buffer[i] = backgroundColor;
    }
}

pub fn setPixel(x: u32, y: u32, color: u32) void {
    buffer[(W * y) + x] = color;
}

pub fn drawSprite(x: u32, y: u32, sprite: ds.Sprite) void {
    for (0..sprite.sizeY) |i| {
        for (0..sprite.sizeX) |j| {
            if (y + i < H and x + j < W) {
                setPixel(@intCast(x + j), @intCast(y + i), sprite.getPixel(@intCast(j), @intCast(i)));
            }
        }
    }
}

pub fn drawObject(o: ds.Object) void {
    drawSprite(o.pos.roundX(), o.pos.roundY(), o.sprite);
}
pub fn addPlayerX(delta: f32) void {
    player.pos.x += delta;
    const maxPos: f32 = @floatFromInt(W - player.sprite.sizeX);
    player.pos.x = std.math.clamp(player.pos.x, 0, maxPos);
}

pub fn addEnemyX(delta: f32) bool {
    var maxX: u32 = 0;
    var minX: u32 = W;
    for (enemies, 0..) |row, y| {
        for (row, 0..) |enemy, x| {
            if (enemy) |e| {
                enemies[y][x].?.pos.x += delta;
                const maxPos: f32 = @floatFromInt(W - e.sprite.sizeX);
                enemies[y][x].?.pos.x = std.math.clamp(enemies[y][x].?.pos.x, 0, maxPos);

                if (maxX < enemies[y][x].?.pos.roundX() + e.sprite.sizeX) {
                    maxX = enemies[y][x].?.pos.roundX() + e.sprite.sizeX;
                }
                if (minX > enemies[y][x].?.pos.roundX()) {
                    minX = enemies[y][x].?.pos.roundX();
                }
            }
        }
    }
    return minX <= 0 or maxX >= W;
}

pub fn addEnemyY(delta: f32) bool {
    var maxY: u32 = 0;
    var minY: u32 = H;
    for (enemies, 0..) |row, y| {
        for (row, 0..) |enemy, x| {
            if (enemy) |e| {
                enemies[y][x].?.pos.y += delta;
                const maxPos: f32 = @floatFromInt(H - e.sprite.sizeY);
                enemies[y][x].?.pos.y = std.math.clamp(enemies[y][x].?.pos.y, 0, maxPos);
                if (maxY < enemies[y][x].?.pos.roundY() + e.sprite.sizeY) {
                    maxY = enemies[y][x].?.pos.roundY() + e.sprite.sizeY;
                }
                if (minY > enemies[y][x].?.pos.roundY()) {
                    minY = enemies[y][x].?.pos.roundY();
                }
            }
        }
    }
    return minY <= 0 or maxY >= H;
}

pub fn updateProjectiles(deltaTime: f32) void {
    for (projectiles, 0..) |p, i| {
        if (p) |_| {
            projectiles[i].?.obj.pos.y += deltaTime * projectileSpeed * projectiles[i].?.dir;
            if (projectiles[i].?.obj.pos.roundY() >= H) {
                projectiles[i] = null;
            }
        }
    }
}

pub fn addProjectile(proj: ds.Projectile) void {
    for (projectiles, 0..) |p, i| {
        if (p) |_| {} else {
            projectiles[i] = proj;
            break;
        }
    }
}

pub fn addDeathMarker(dm: ds.DeathMarker) void {
    for (deathMarkers, 0..) |d, i| {
        if (d) |_| {} else {
            deathMarkers[i] = dm;
            break;
        }
    }
}

pub fn updateCollision() void {
    for (projectiles, 0..) |pr, i| {
        if (pr) |p| {
            for (enemies, 0..) |row, y| {
                for (row, 0..) |enemy, x| {
                    if (enemy) |e| {
                        if (areColliding(e, p.obj)) {
                            addDeathMarker(ds.DeathMarker{ .obj = ds.Object{ .pos = e.pos, .sprite = ds.Sprite{ .sizeX = blockSize, .sizeY = blockSize, .pixels = &enemyDeathSprite } }, .lifetime = 1e5, .creationTime = std.time.microTimestamp() });
                            points += pointsByRow[y];
                            std.debug.print("added {d} points, current = {d}", .{ pointsByRow[y], points });

                            projectiles[i] = null;
                            enemies[y][x] = null;
                        }
                    }
                }
            }
        }
    }
}

pub fn areColliding(o1: ds.Object, o2: ds.Object) bool {
    return o1.pos.roundX() < o2.pos.roundX() + o2.sprite.sizeX and
        o1.pos.roundX() + o1.sprite.sizeX > o2.pos.roundX() and
        o1.pos.roundY() < o2.pos.roundY() + o2.sprite.sizeY and
        o1.pos.roundY() + o1.sprite.sizeY > o2.pos.roundY();
}

pub fn main() void {
    try clearConsole();
    w.createWindow(W, H, &buffer);
    var deltaTime: f32 = 0;
    var enemyGoingLeft = false;
    var shootTime = std.time.microTimestamp();
    createEnemies();

    while (w.tickWindow(&playerInput)) {
        const startTime = std.time.microTimestamp();
        clearBuffer();
        drawObject(player);
        for (enemies) |row| {
            for (row) |enemy| {
                if (enemy) |e| {
                    drawObject(e);
                }
            }
        }

        for (projectiles) |pr| {
            if (pr) |p| {
                drawObject(p.obj);
            }
        }

        for (deathMarkers, 0..) |dm, i| {
            if (dm) |o| {
                drawObject(o.obj);
                if (std.time.microTimestamp() - o.creationTime > o.lifetime) {
                    deathMarkers[i] = null;
                }
            }
        }

        if (playerInput.left) {
            addPlayerX(-0.001 * deltaTime);
        } else if (playerInput.right) {
            addPlayerX(0.001 * deltaTime);
        } else if (playerInput.shoot and std.time.microTimestamp() - shootTime > shootCooldownMicro) {
            addProjectile(ds.Projectile{ .obj = ds.Object{ .pos = .{ .x = player.pos.x, .y = player.pos.y + projectileSpawnDistance }, .sprite = ds.Sprite{ .sizeX = 10, .sizeY = blockSize, .pixels = &projectileSprite } }, .dir = 1 });
            shootTime = std.time.microTimestamp();
        }

        var reachedEnd: bool = false;
        if (enemyGoingLeft) {
            reachedEnd = addEnemyX(-0.0001 * deltaTime);
        } else {
            reachedEnd = addEnemyX(0.0001 * deltaTime);
        }
        if (reachedEnd) {
            std.debug.print("reached End", .{});
            _ = addEnemyY(-blockSize + blockOffset);
            enemyGoingLeft = !enemyGoingLeft;
        }
        updateCollision();
        updateProjectiles(deltaTime);
        w.redraw();
        deltaTime = @floatFromInt(std.time.microTimestamp() - startTime);
    }
}
