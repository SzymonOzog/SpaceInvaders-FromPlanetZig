const std = @import("std");
const w = @cImport({
    @cInclude("windows.h");
    @cInclude("winuser.h");
});

pub fn testFn() !void {
    std.debug.print("Error at FillConsoleOutputCharacterA", .{});
}

pub fn wndproc(p1: w.HWND, p2: w.UINT, p3: w.WPARAM, p4: w.LPARAM) callconv(.C) w.LRESULT {
    return w.DefWindowProcA(p1, p2, p3, p4);
}

var handle: w.HWND = undefined;
var msg: w.MSG = undefined;

pub fn isWindowOpen() bool {
    return w.IsWindow(handle) == 1;
}

pub fn tickWindow() bool {
    if (w.GetMessageA(&msg, handle, 0, 0) == 0) {
        std.debug.print("Error at GetMessageA", .{});
        return false;
    }
    _ = w.TranslateMessage(&msg);
    _ = w.DispatchMessageA(&msg);
    return isWindowOpen();
}

pub fn createWindow(width: u16, height: u16) !void {
    const name = "window";
    const wclass = w.WNDCLASSA{
        .style = w.CS_HREDRAW | w.CS_VREDRAW,
        .lpfnWndProc = &wndproc,
        .lpszMenuName = name.ptr,
        .lpszClassName = name.ptr,
        .hIcon = 0,
        .hInstance = 0,
        .hCursor = 0,
        .hbrBackground = w.COLOR_WINDOW,
        .cbClsExtra = 0,
        .cbWndExtra = 0,
    };
    if (w.RegisterClassA(&wclass) == 0) {
        std.debug.print("Error at RegisterClass", .{});
    }

    handle = w.CreateWindowExA(0, wclass.lpszClassName, wclass.lpszMenuName, 0x00080000, 200, 200, width, height, 0, 0, 0, undefined);
    if (handle == 0) {
        std.debug.print("Error at createaWindow", .{});
    }
    _ = w.ShowWindow(handle, w.SW_SHOWDEFAULT);
}
