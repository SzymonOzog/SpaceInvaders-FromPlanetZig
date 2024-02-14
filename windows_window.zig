const std = @import("std");
const ds = @import("data_structures.zig");
const config = @import("config");
const tracy = @import("tracy.zig");
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
    if (config.tracy) {
        const tr = tracy.trace(@src());
        defer tr.end();
    }
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

    const startTime = std.time.microTimestamp();
    const allocator = std.heap.page_allocator;
    const outBuffer: []u32 = allocator.alloc(u32, @intCast(W * H)) catch return;
    defer allocator.free(outBuffer);
    const he: u32 = @intCast(H);
    const wi: u32 = @intCast(W);

    const precision: u32 = 1024;
    const wStep: u32 = (width * precision) / wi;
    const hStep: u32 = (height * precision) / he;
    var inY: u32 = 0;
    var outY: u32 = 0;
    for (0..he) |_| {
        var inX: u32 = 0;
        for (0..wi) |x| {
            const inIdx: u32 = (inY / precision) * width + inX / precision;
            outBuffer[outY + x] = buffer[inIdx];
            inX += wStep;
        }
        outY += wi;
        inY += hStep;
    }
    std.debug.print("upscale took {d}", .{std.time.microTimestamp() - startTime});

    const bitsSet = w.SetDIBitsToDevice(hdc, 0, 0, @intCast(W), @intCast(H), 0, 0, 0, @intCast(H), outBuffer.ptr, &bInfo, w.DIB_RGB_COLORS);
    if (H != bitsSet) {
        std.debug.print("\n bits set = {d}, h = {d}", .{ bitsSet, H });
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

pub fn createWindow(bufferW: u32, bufferH: u32, buffer: []u32, windowUpsample: u32) void {
    width = bufferW;
    height = bufferH;
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

    handle = w.CreateWindowExA(0, wclass.lpszClassName, wclass.lpszMenuName, w.WS_TILEDWINDOW, 200, 200, @intCast(width * windowUpsample), @intCast(height * windowUpsample), 0, 0, 0, undefined);
    if (handle == 0) {
        std.debug.print("Error at createaWindow", .{});
    }
    _ = w.ShowWindow(handle, w.SW_SHOWDEFAULT);
}
