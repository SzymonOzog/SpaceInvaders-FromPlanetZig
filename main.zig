const std = @import("std");
const w = @import("windows_window.zig");
const game = @import("game.zig");
const ds = @import("data_structures.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    try game.init(arena.allocator());

    var playerInput = ds.PlayerInput{ .left = false, .right = false, .shoot = false };
    w.createWindow(game.W, game.H, game.renderer.buffer, 4);
    while (w.tickWindow(&playerInput)) {
        w.redraw();
        try game.advanceFrame(playerInput);
    }
}
