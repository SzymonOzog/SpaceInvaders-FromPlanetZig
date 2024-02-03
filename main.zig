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
        var tl: COORD = .{ .X = 0, .Y = 0 };
        var written: DWORD = undefined;
        std.debug.print("\nterm size {d}, {d}!\n", .{ csbi.dwSize.X, csbi.dwSize.Y });
        var consoleX: u32 = @intCast(csbi.dwSize.X);
        var consoleY: u32 = @intCast(csbi.dwSize.Y);
        var cells = consoleX * consoleY;

        if (kernel32.FillConsoleOutputCharacterA(stdoutHandle, ' ', cells, tl, &written) == 0) {
            std.debug.print("Error at FillConsoleOutputCharacterA", .{});
        } else if (kernel32.FillConsoleOutputAttribute(stdoutHandle, csbi.wAttributes, cells, tl, &written) == 0) {
            std.debug.print("Error at FillConsoleOutputAttribute", .{});
        } else if (kernel32.SetConsoleCursorPosition(stdoutHandle, tl) == 0) {
            std.debug.print("Error at SetConsoleCursorPosition", .{});
        }
    }
}
pub fn main() void {
    try clearConsole();
    try w.createWindow(800, 500);
    while (w.tickWindow()) {}
}
