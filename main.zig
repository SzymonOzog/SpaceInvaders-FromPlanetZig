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
const W: u32 = 800;
const H: u32 = 600;
const backgroundColor = 0xFF;
var buffer: [W * H]u32 = [1]u32{backgroundColor} ** (W * H);

const player: [blockSize][blockSize]u32 = [_][blockSize]u32{[_]u32{0xFF00} ** blockSize} ** blockSize;

const enemy1: [blockSize][blockSize]u32 = [_][blockSize]u32{[_]u32{0xFF0000} ** blockSize} ** blockSize;
const enemy2: [blockSize][blockSize]u32 = [_][blockSize]u32{[_]u32{0xAFFF00} ** blockSize} ** blockSize;
const enemy3: [blockSize][blockSize]u32 = [_][blockSize]u32{[_]u32{0xEFFF00} ** blockSize} ** blockSize;

const enemies: [5][11][blockSize][blockSize]u32 = .{ .{enemy1} ** 11, .{enemy2} ** 11, .{enemy2} ** 11, .{enemy3} ** 11, .{enemy3} ** 11 };

var projectile: [blockSize][10]u32 = [_][10]u32{[_]u32{0xFFFFFF} ** 10} ** blockSize;
const projectileSpeed: f32 = 0.001;
const projectileSpawnDistance: f32 = blockSize;
const shootCooldownMicro = 1e6;

var projectiles: [100]?ds.Projectile = .{null} ** 100;

var enemyPos = ds.Position{ .x = 0, .y = 400 };
var playerPos = ds.Position{ .x = 0, .y = 100 };

var playerInput = ds.PlayerInput{ .left = false, .right = false, .shoot = false };

pub fn clearBuffer() void {
    for (0..buffer.len) |i| {
        buffer[i] = backgroundColor;
    }
}

pub fn setPixel(x: u32, y: u32, color: u32) void {
    buffer[(W * y) + x] = color;
}

pub fn drawSprite(x: u32, y: u32, sprite: anytype) void {
    for (0.., sprite) |i, row| {
        for (0.., row) |j, pixel| {
            if (y + i < H and x + j < W) {
                setPixel(@intCast(x + j), @intCast(y + i), pixel);
            }
        }
    }
}

var enemyS: [blockSize * blockSize]u32 = .{0xFFFFFF} ** (blockSize * blockSize);
const EnemySprite = ds.Sprite{ .sizeY = enemy1.len, .sizeX = enemy1[0].len, .pixels = &enemyS };

pub fn addPlayerX(delta: f32) void {
    playerPos.x += delta;
    playerPos.x = std.math.clamp(playerPos.x, 0, @as(f32, W - player[0].len));
}

pub fn addEnemyX(delta: f32) bool {
    enemyPos.x += delta;
    const enemiesSize = enemies[0].len * (blockSize + blockOffset);
    const reachedEnd: bool = enemyPos.x < 0 or enemyPos.x > (W - enemiesSize);
    enemyPos.x = std.math.clamp(enemyPos.x, 0, @as(f32, W - enemiesSize));
    return reachedEnd;
}

pub fn updateProjectiles(deltaTime: f32) void {
    for (projectiles, 0..) |p, i| {
        if (p) |_| {
            projectiles[i].?.pos.y += deltaTime * projectileSpeed * projectiles[i].?.dir;
            if (projectiles[i].?.pos.roundY() >= H) {
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

pub fn main() void {
    try clearConsole();
    w.createWindow(W, H, &buffer);
    var deltaTime: f32 = 0;
    var enemyGoingLeft = false;
    var shootTime = std.time.microTimestamp();
    while (w.tickWindow(&playerInput)) {
        const startTime = std.time.microTimestamp();
        clearBuffer();
        drawSprite(@intFromFloat(playerPos.x), @intFromFloat(playerPos.y), player);
        const eX: u32 = @intFromFloat(enemyPos.x);
        const eY: u32 = @intFromFloat(enemyPos.y);
        for (enemies, 0..) |row, y| {
            for (row, 0..) |enemy, x| {
                drawSprite(@intCast(eX + x * (blockSize + blockOffset)), @intCast(eY - y * (blockSize + blockOffset)), enemy);
            }
        }

        for (projectiles) |pr| {
            if (pr) |p| {
                drawSprite(p.pos.roundX(), p.pos.roundY(), projectile);
            }
        }

        if (playerInput.left) {
            addPlayerX(-0.001 * deltaTime);
        } else if (playerInput.right) {
            addPlayerX(0.001 * deltaTime);
        } else if (playerInput.shoot and std.time.microTimestamp() - shootTime > shootCooldownMicro) {
            addProjectile(ds.Projectile{ .pos = .{ .x = playerPos.x, .y = playerPos.y + projectileSpawnDistance }, .dir = 1 });
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
            enemyPos.y -= (blockSize + blockOffset);
            enemyGoingLeft = !enemyGoingLeft;
        }
        updateProjectiles(deltaTime);
        w.redraw();
        deltaTime = @floatFromInt(std.time.microTimestamp() - startTime);
    }
}
