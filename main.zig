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

const blockSize = 30
const W: u32 = 800;
const H: u32 = 600;
const backgroundColor = 0xFF;
var buffer: [W * H]u32 = [1]u32{backgroundColor} ** (W * H);

const player: [30][30]u32 = [_][30]u32{[_]u32{0xFF00} ** 30} ** 30;

const enemy1: [30][30]u32 = [_][30]u32{[_]u32{0xFF0000} ** 30} ** 30;
const enemy2: [30][30]u32 = [_][30]u32{[_]u32{0xAFFF00} ** 30} ** 30;
const enemy3: [30][30]u32 = [_][30]u32{[_]u32{0xEFFF00} ** 30} ** 30;
const enemies: [5][11][30][30]u32 = .{ .{enemy1} ** 11, .{enemy2} ** 11, .{enemy2} ** 11, .{enemy3} ** 11, .{enemy3} ** 11 };

const projectile: [30][10]u32 = [_][10]u32{[_]u32{0xFFFFFF} ** 10} ** 30;

var enemyPos = ds.Position{ .x = 0, .y = 400 };
var playerPos = ds.Position{ .x = 0, .y = 100 };


var playerInput = ds.PlayerInput{ .left = false, .right = false, .shoot = false };
var foo: [4]u8 = .{ 4, 3, 2, 8 };

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
            setPixel(@intCast(x + j), @intCast(y + i), pixel);
        }
    }
}

pub fn addPlayerX(delta: f32) void {
    playerPos.x += delta;
    playerPos.x = std.math.clamp(playerPos.x, 0, @as(f32, W - player[0].len));
}

pub fn addEnemyX(delta: f32) bool {
    enemyPos.x += delta;
    const enemiesSize = enemies[0].len * 40;
    const reachedEnd: bool = enemyPos.x < 0 or enemyPos.x > (W - enemiesSize);
    enemyPos.x = std.math.clamp(enemyPos.x, 0, @as(f32, W - enemiesSize));
    return reachedEnd;
}

pub fn main() void {
    try clearConsole();
    w.createWindow(W, H, &buffer);
    var deltaTime: f32 = 0;
    var enemyGoingLeft = false;
    while (w.tickWindow(&playerInput)) {
        const startTime = std.time.microTimestamp();
        clearBuffer();
        drawSprite(@intFromFloat(playerPos.x), @intFromFloat(playerPos.y), player);
        drawSprite(200, 299, projectile);
        const eX: u32 = @intFromFloat(enemyPos.x);
        const eY: u32 = @intFromFloat(enemyPos.y);
        for (enemies, 0..) |row, y| {
            for (row, 0..) |enemy, x| {
                drawSprite(@intCast(eX + x * 40), @intCast(eY - y * 40), enemy);
            }
        }

        if (playerInput.left) {
            addPlayerX(-0.001 * deltaTime);
        } else if (playerInput.right) {
            addPlayerX(0.001 * deltaTime);
        } else if (playerInput.shoot) {
            std.debug.print("pressed shoot", .{});
        }

        var reachedEnd: bool = false;
        if (enemyGoingLeft) {
            reachedEnd = addEnemyX(-0.0001 * deltaTime);
        } else {
            reachedEnd = addEnemyX(0.0001 * deltaTime);
        }
        if (reachedEnd) {
            std.debug.print("reached End", .{});
            enemyPos.y -= 50;
            enemyGoingLeft = !enemyGoingLeft;
        }
        w.redraw();
        deltaTime = @floatFromInt(std.time.microTimestamp() - startTime);
    }
}
