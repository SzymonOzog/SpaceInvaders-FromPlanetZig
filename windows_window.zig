const std = @import("std");
const ds = @import("data_structures.zig");
const w = @cImport({
    @cInclude("windows.h");
});

pub fn wndproc(hwnd: w.HWND, msg: w.UINT, wParam: w.WPARAM, lParam: w.LPARAM) callconv(.C) w.LRESULT {
    if (msg == w.WM_PAINT) {
        drawBuffer(scrBuffer);
    }
    return w.DefWindowProcA(hwnd, msg, wParam, lParam);
}

var handle: w.HWND = undefined;

var width: u32 = undefined;
var height: u32 = undefined;

pub var scrBuffer: []u32 = undefined;

const VK_H = 0x48;
const VK_L = 0x4C;
const VK_SPACE = 0x20;

pub fn isWindowOpen() bool {
    return w.IsWindow(handle) == 1;
}

pub fn tickWindow(input: *ds.PlayerInput) bool {
    var msg: w.MSG = undefined;
    if (w.GetMessageA(&msg, handle, 0, 0) == 0) {
        std.debug.print("Error at GetMessageA {d}", .{w.GetLastError()});
        return false;
    }
    _ = w.TranslateMessage(&msg);
    _ = w.DispatchMessageA(&msg);
    if (msg.message == w.WM_KEYDOWN) {
        if (msg.wParam == VK_H) {
            input.*.left = true;
        } else if (msg.wParam == VK_L) {
            input.*.right = true;
        } else if (msg.wParam == VK_SPACE) {
            input.*.shoot = true;
        }
    } else if (msg.message == w.WM_KEYUP) {
        if (msg.wParam == VK_H) {
            input.*.left = false;
        } else if (msg.wParam == VK_L) {
            input.*.right = false;
        } else if (msg.wParam == VK_SPACE) {
            input.*.shoot = false;
        }
    }
    return isWindowOpen();
}

pub fn drawBuffer(buffer: []u32) void {
    var rect = w.RECT{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
    _ = w.GetWindowRect(handle, &rect);
    const W = rect.right - rect.left;
    const H = rect.bottom - rect.top;

    var ps: w.PAINTSTRUCT = w.PAINTSTRUCT{
        .hdc = undefined,
        .fErase = 1,
        .fRestore = 0,
        .fIncUpdate = 0,
        .rcPaint = rect,
        .rgbReserved = undefined,
    };
    const hdc = w.BeginPaint(handle, &ps);

    const bInfoHeader = w.BITMAPINFOHEADER{ .biSize = @sizeOf(w.BITMAPINFOHEADER), .biWidth = W, .biHeight = H, .biPlanes = 1, .biBitCount = 32, .biCompression = 0, .biSizeImage = 0, .biClrUsed = 0, .biClrImportant = 0, .biYPelsPerMeter = 0, .biXPelsPerMeter = 0 };

    var bInfo = w.BITMAPINFO{ .bmiHeader = bInfoHeader, .bmiColors = undefined };

    const allocator = std.heap.page_allocator;
    const outBuffer: []u32 = allocator.alloc(u32, @intCast(W * H)) catch return;
    defer allocator.free(outBuffer);
    const he: u64 = @intCast(H);
    const wi: u32 = @intCast(W);
    for (0..he) |y| {
        for (0..wi) |x| {
            const outIdx = y * wi + x;
            const wMap: u32 = @intFromFloat(@as(f32, @floatFromInt(x)) * @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(wi)));
            const hMap: u32 = @intFromFloat(@as(f32, @floatFromInt(y)) * @as(f32, @floatFromInt(height)) / @as(f32, @floatFromInt(he)));
            const inIdx = wMap + hMap * width;
            outBuffer[outIdx] = buffer[inIdx];
            if (x < 5 and y < 9) {
                std.debug.print("out {d} in {d} width {d} height {d} outwidth {d} outheight {d}\n", .{ outIdx, inIdx, width, height, wi, he });
            }
        }
    }

    if (height != w.SetDIBitsToDevice(hdc, 0, 0, @intCast(W), @intCast(H), 0, 0, 0, @intCast(W), outBuffer.ptr, &bInfo, w.DIB_RGB_COLORS)) {
        std.debug.print("\n {d}", .{w.GetLastError()});
    }
    if (w.EndPaint(handle, &ps) == 0) {}
}

pub fn redraw() void {
    var rect = w.RECT{ .left = 0, .top = 0, .right = 0, .bottom = 0 };
    if (w.GetWindowRect(handle, &rect) == 0) {
        std.debug.print("Error at GetWindowRect {d}", .{w.GetLastError()});
    }
    const invalidationRect = w.RECT{ .left = 0, .top = 0, .right = rect.right - rect.left, .bottom = rect.bottom - rect.top };
    if (w.InvalidateRect(handle, &invalidationRect, 0) == 0) {
        std.debug.print("Error at InvalidateRect {d}", .{w.GetLastError()});
    }
}

pub fn createWindow(inWidth: u32, inHeight: u32, buffer: []u32) void {
    width = inWidth;
    height = inHeight;
    scrBuffer = buffer;
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

    handle = w.CreateWindowExA(0, wclass.lpszClassName, wclass.lpszMenuName, w.WS_TILEDWINDOW, 200, 200, @intCast(width), @intCast(height), 0, 0, 0, undefined);
    if (handle == 0) {
        std.debug.print("Error at createaWindow", .{});
    }
    _ = w.ShowWindow(handle, w.SW_SHOWDEFAULT);
}
