const std = @import("std");
const ds = @import("data_structures.zig");

var keys: [][]const u8 = undefined;

pub fn init(allocator: std.mem.Allocator) !std.StringHashMap(ds.Sprite) {
    var spriteMap = std.StringHashMap(ds.Sprite).init(allocator);
    const symbols = "abcdefghijklmnopqrstuvwxyz0123456789<>=*?-";
    var x: u32 = 1;
    var y: u32 = 68;
    const xStep = 10;
    const yStep = 10;
    const xSize = 6;
    const ySize = 8;
    const width = 8;
    try spriteMap.put(" ", ds.Sprite{ .sheetX = 0, .sheetY = 0, .sizeX = xSize, .sizeY = ySize, .mask = null, .color = 0xF00FF00 });
    for (symbols, 0..) |_, i| {
        const str = symbols[i .. i + 1];
        try spriteMap.put(str, ds.Sprite{ .sizeX = xSize, .sizeY = ySize, .sheetX = x, .sheetY = y, .mask = null, .color = 0xFFFFFF });
        x += xStep;
        if ((i + 1) % width == 0) {
            x = 1;
            y += yStep;
        }
    }
    try spriteMap.put("player", ds.Sprite{ .sheetX = 1, .sheetY = 49, .sizeX = 15, .sizeY = 7, .mask = null, .color = 0x00FF00 });
    try spriteMap.put("playerProjectile", ds.Sprite{ .sheetX = 51, .sheetY = 21, .sizeX = 3, .sizeY = 7, .mask = null, .color = 0xFFFFFF });
    try spriteMap.put("playerDeath", ds.Sprite{ .sheetX = 19, .sheetY = 49, .sizeX = 15, .sizeY = 7, .mask = null, .color = 0x00FF00, .animations = 2, .animX = 18 });
    try spriteMap.put("enemy1", ds.Sprite{ .sheetX = 1, .sheetY = 1, .sizeX = 15, .sizeY = 7, .mask = null, .color = 0xFFFFFF, .animations = 2, .animY = 9 });
    try spriteMap.put("enemy2", ds.Sprite{ .sheetX = 19, .sheetY = 1, .sizeX = 15, .sizeY = 7, .mask = null, .color = 0xFFFFFF, .animations = 2, .animY = 9 });
    try spriteMap.put("enemy3", ds.Sprite{ .sheetX = 37, .sheetY = 1, .sizeX = 15, .sizeY = 7, .mask = null, .color = 0xFFFFFF, .animations = 2, .animY = 9 });
    try spriteMap.put("enemyDeath", ds.Sprite{ .sheetX = 55, .sheetY = 1, .sizeX = 15, .sizeY = 7, .mask = null, .color = 0xFFFFFF });
    try spriteMap.put("enemyProjectile", ds.Sprite{ .sheetX = 1, .sheetY = 21, .sizeX = 3, .sizeY = 7, .mask = null, .color = 0xFFFFFF, .animations = 4, .animX = 5 });
    try spriteMap.put("mysteryShip", ds.Sprite{ .sheetX = 1, .sheetY = 39, .sizeX = 15, .sizeY = 7, .mask = null, .color = 0xFF0000 });
    try spriteMap.put("bunker", ds.Sprite{ .sheetX = 47, .sheetY = 31, .sizeX = 21, .sizeY = 15, .mask = null, .color = 0x00FF00 });
    return spriteMap;
}
