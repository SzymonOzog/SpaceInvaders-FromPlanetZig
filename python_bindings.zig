const game = @import("game.zig");
const std = @import("std");

var arena: std.heap.ArenaAllocator = undefined;

pub export fn init() callconv(.C) bool {
    arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    game.init(arena.allocator()) catch return false;
    return true;
}

pub export fn getFrame() callconv(.C) [*]u32 {
    return game.renderer.buffer.ptr;
}

pub export fn getReward() callconv(.C) i32 {
    return game.reward;
}

pub export fn getWidth() callconv(.C) u32 {
    return game.W;
}

pub export fn getHeight() callconv(.C) u32 {
    return game.H;
}

pub export fn advanceFrame(left: bool, right: bool, shoot: bool) callconv(.C) i32 {
    game.advanceFrame(.{ .left = left, .right = right, .shoot = shoot }) catch return -1;
    return 0;
}

pub export fn isOver() callconv(.C) bool {
    return game.gameOver;
}

pub export fn resetState() callconv(.C) bool {
    game.resetState() catch return false;
    return true;
}

pub export fn deinit() callconv(.C) void {
    arena.deinit();
}

pub export fn setDeltaTimeScale(scale: u32) callconv(.C) void {
    game.deltaTimeScale = scale;
}
