const std = @import("std");
const windows = std.os.windows;
const kernel32 = windows.kernel32;
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
pub fn main() void {
    try clearConsole();
    while (w.tickWindow()) {}
    w.createWindow(W, H, &buffer);
        w.redraw();
}
