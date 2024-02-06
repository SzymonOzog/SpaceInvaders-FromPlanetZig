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

const W: u32 = 800;
const H: u32 = 600;
var buffer: [W * H]u32 = [1]u32{0xFF} ** (W * H);

const spr: [100][10]u32 = [_][10]u32{[_]u32{0xFFFF} ** 10}**100;
const player: [30][30]u32 = [_][30]u32{[_]u32{0xFF00} ** 30}**30;
const enemy: [30][30]u32 = [_][30]u32{[_]u32{0xFFFF00} ** 30}**30;

var playerInput = ds.PlayerInput{.left = false, .right = false, .shoot = false};

pub fn setPixel(x:u32, y:u32, color:u32) void{
    buffer[(W*y)+x] = color;
}

pub fn drawSprite(x:u32, y:u32, comptime sizeX:u32, comptime sizeY:u32, sprite:[sizeX][sizeY]u32) void{
    for (0.., sprite) |i, row|{
        for (0.., row) |j, pixel|{
            setPixel(@intCast(x+j), @intCast(y+i), pixel);
        }
    }
}

pub fn main() void {
    try clearConsole();
    w.createWindow(W, H, &buffer);
    while (w.tickWindow(&playerInput)) {
        drawSprite(400,220,30,30, player);
        drawSprite(400,20,30,30, enemy);
        if(playerInput.left){
            std.debug.print("pressed left", .{});
        } else if(playerInput.right){
            std.debug.print("pressed right", .{});
        } else if(playerInput.shoot){
            std.debug.print("pressed shoot", .{});
        }
        w.redraw();
    }
}
