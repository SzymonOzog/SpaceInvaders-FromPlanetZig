const std = @import("std");
const ds = @import("data_structures.zig");
const w = @import("windows_window.zig");
const zigimg = @import("zigimg");
const sprites = @import("sprites.zig");

var prng = std.rand.DefaultPrng.init(37);
const rand = prng.random();

const blockSize = 8;
const blockOffset = 2;
const enemyMoveDeltaX = blockOffset;
const enemyMoveDeltaY = blockSize + blockOffset;
const maxWorldStepTime: u32 = 1e6;
var worldStepTime: u32 = maxWorldStepTime;
var speedupAmount: u32 = 1e4;

const pointsByRow: [5]u32 = .{ 30, 20, 20, 10, 10 };
const W: u32 = 224;
const H: u32 = 256;
const backgroundColor = 0xFF;
const playerSpeed: f32 = 0.0001;
const bunkerOffset = (blockSize + blockOffset) * 5;
var buffer: [W * H]u32 = [1]u32{backgroundColor} ** (W * H);

var spriteSheet: []bool = undefined;
var spriteSheetW: u32 = undefined;
var spriteMap: std.StringHashMap(ds.Sprite) = undefined;

var playerInput = ds.PlayerInput{ .left = false, .right = false, .shoot = false };

var player: ?ds.Object = null;
var playerDeathMarker: ?ds.DeathMarker = null;
var points: u32 = 0;
var lifes: u32 = 3;
const playerStart: ds.Position = ds.Position{ .x = 0, .y = blockSize };

var enemies: [5][11]?ds.Object = .{.{null} ** 11} ** 5;
var deathMarkers: [100]?ds.DeathMarker = .{null} ** 100;
var numEnemiesAlive: u32 = 0;
var mysteryShip: ?ds.Object = null;
const mysteryShipSpeed: f32 = 0.00003;
const mysteryShipPoints: u32 = 150;

var bunkers: [4]?ds.Bunker = .{null} ** 4;

var objectList: std.ArrayList(*ds.Object) = undefined;
var spawnedObjects: u32 = 0;

pub fn respawnPlayer() !void {
    player = ds.Object{ .pos = playerStart, .sprite = spriteMap.get("player").? };
    try registerObject(&player.?);
}

pub fn spawnMysteryShip() !void {
    const offset: f32 = (enemies.len + 11) * enemyMoveDeltaY;
    mysteryShip = ds.Object{ .pos = ds.Position{ .x = 0, .y = playerStart.y + offset }, .sprite = spriteMap.get("mysteryShip").? };
    try registerObject(&mysteryShip.?);
}

pub fn createEnemies(round: u32) !void {
    const enemyBlock = enemies.len + 10 - (round % 10);
    const initialOffset: f32 = @floatFromInt(enemyBlock * enemyMoveDeltaY);
    const enemyStartPos = ds.Position{ .y = playerStart.y + initialOffset, .x = 10 };
    numEnemiesAlive = enemies.len * enemies[0].len;
    var offsetX: f32 = 0;
    var offsetY: f32 = 0;
    for (enemies, 0..) |row, y| {
        var sprite: ds.Sprite = undefined;
        for (row, 0..) |_, x| {
            const pos = ds.Position{ .x = enemyStartPos.x + offsetX, .y = enemyStartPos.y - offsetY };
            if (y < 1) {
                sprite = spriteMap.get("enemy1").?;
            } else if (y < 3) {
                sprite = spriteMap.get("enemy2").?;
            } else {
                sprite = spriteMap.get("enemy3").?;
            }
            enemies[y][x] = ds.Object{ .pos = pos, .sprite = sprite };
            offsetX += @floatFromInt(sprite.sizeX);
            try registerObject(&enemies[y][x].?);
        }
        offsetY += @floatFromInt(sprite.sizeY + blockOffset);
        offsetX = 0;
    }
}

const projectileSpeed: f32 = 0.0001;
const projectileSpawnDistance: f32 = blockSize;
const shootCooldownMicro = 1e5;

var projectiles: [100]?ds.Projectile = .{null} ** 100;

pub fn clearBuffer() void {
    for (0..buffer.len) |i| {
        buffer[i] = backgroundColor;
    }
}

pub fn setPixel(x: u32, y: u32, color: u32) void {
    if (color < 0x01000000) {
        buffer[(W * y) + x] = color;
    }
}

pub fn drawSprite(x: u32, y: u32, sprite: ds.Sprite) void {
    for (0..sprite.sizeY) |i| {
        for (0..sprite.sizeX) |j| {
            if (y + i < H and x + j < W and spriteSheet[((sprite.getCurrentSheetY() + sprite.sizeY - i) * spriteSheetW + sprite.getCurrentSheetX() + j)]) {
                if (sprite.mask) |m| {
                    if (m[i * sprite.sizeX + j]) {
                        setPixel(@intCast(x + j), @intCast(y + i), sprite.color);
                    }
                } else {
                    setPixel(@intCast(x + j), @intCast(y + i), sprite.color);
                }
            }
        }
    }
}

pub fn drawObject(o: ds.Object) void {
    drawSprite(o.pos.roundX(), o.pos.roundY(), o.sprite);
}

pub fn drawText(text: []const u8, x: u32, y: u32) void {
    var cursor = x;
    for (text) |c| {
        const str: [1]u8 = .{c};
        if (spriteMap.get(&str)) |s| {
            drawSprite(cursor, y, s);
            cursor += s.sizeX;
        }
    }
}

pub fn addPlayerX(delta: f32) void {
    player.?.pos.x += delta;
    const maxPos: f32 = @floatFromInt(W - player.?.sprite.sizeX);
    player.?.pos.x = std.math.clamp(player.?.pos.x, 0, maxPos);
}

pub fn addEnemyX(delta: f32) bool {
    var reachedEnd = false;
    for (enemies, 0..) |row, y| {
        for (row, 0..) |enemy, x| {
            if (enemy) |e| {
                const newPos: f32 = enemies[y][x].?.pos.x + delta;
                const maxPos: f32 = @floatFromInt(W - e.sprite.sizeX);
                if (newPos + delta <= 0 or newPos + delta >= maxPos) {
                    reachedEnd = true;
                }
                enemies[y][x].?.pos.x = newPos;
            }
        }
    }
    return reachedEnd;
}

pub fn addEnemyY(delta: f32) bool {
    var reachedEnd = false;
    for (enemies, 0..) |row, y| {
        for (row, 0..) |enemy, x| {
            if (enemy) |e| {
                const newPos: f32 = enemies[y][x].?.pos.y + delta;
                const spriteSizeFloat: f32 = @floatFromInt(e.sprite.sizeY);
                const maxPos: f32 = playerStart.y + spriteSizeFloat;
                if (newPos <= maxPos) {
                    reachedEnd = true;
                }
                enemies[y][x].?.pos.y = newPos;
            }
        }
    }
    return reachedEnd;
}

pub fn updateProjectiles(deltaTime: f32) void {
    for (projectiles, 0..) |p, i| {
        if (p) |_| {
            const newPos = projectiles[i].?.obj.pos.y + deltaTime * projectileSpeed * projectiles[i].?.dir;
            if (newPos >= H or newPos <= 0) {
                try unregisterObject(p.?.obj);
                projectiles[i] = null;
            } else {
                projectiles[i].?.obj.pos.y = newPos;
            }
        }
    }
}

pub fn addProjectile(proj: ds.Projectile) !void {
    for (projectiles, 0..) |p, i| {
        if (p) |_| {} else {
            projectiles[i] = proj;
            try registerObject(&projectiles[i].?.obj);
            break;
        }
    }
}

pub fn addDeathMarker(dm: ds.DeathMarker) !void {
    for (deathMarkers, 0..) |d, i| {
        if (d) |_| {} else {
            deathMarkers[i] = dm;
            try registerObject(&deathMarkers[i].?.obj);
            break;
        }
    }
}

pub fn updateCollision() !void {
    outer: for (projectiles, 0..) |pr, i| {
        if (pr) |p| {
            for (enemies, 0..) |row, y| {
                for (row, 0..) |enemy, x| {
                    if (enemy) |e| {
                        if (p.dir == 1 and areColliding(e, p.obj)) {
                            try addDeathMarker(ds.DeathMarker{ .obj = ds.Object{ .pos = e.pos, .sprite = spriteMap.get("enemyDeath").? }, .lifetime = 1e5, .creationTime = std.time.microTimestamp() });
                            numEnemiesAlive -= 1;
                            points += pointsByRow[y];
                            try unregisterObject(p.obj);
                            projectiles[i] = null;
                            try unregisterObject(e);
                            worldStepTime -= speedupAmount;
                            enemies[y][x] = null;
                            continue :outer;
                        }
                    }
                }
            }
            if (player) |pl| {
                if (p.dir == -1 and areColliding(p.obj, pl)) {
                    try killPlayer();
                    try unregisterObject(p.obj);
                    projectiles[i] = null;
                    continue :outer;
                }
            }
            if (mysteryShip) |s| {
                if (p.dir == 1 and areColliding(p.obj, s)) {
                    try addDeathMarker(ds.DeathMarker{ .obj = ds.Object{ .pos = s.pos, .sprite = spriteMap.get("enemyDeath").? }, .lifetime = 1e5, .creationTime = std.time.microTimestamp() });
                    try unregisterObject(s);
                    mysteryShip = null;
                    try unregisterObject(p.obj);
                    projectiles[i] = null;
                    points += mysteryShipPoints;
                    continue :outer;
                }
            }
            for (&bunkers) |*bunker| {
                if (bunker.*) |*b| {
                    for (&b.*.parts) |*part| {
                        if (part.*) |*pt| {
                            if (areColliding(p.obj, pt.*.obj)) {
                                if (pt.*.onHit()) {
                                    try unregisterObject(pt.*.obj);
                                    part.* = null;
                                }
                                try unregisterObject(p.obj);
                                projectiles[i] = null;
                                continue :outer;
                            }
                        }
                    }
                }
            }
        }
    }
}

pub fn areColliding(o1: ds.Object, o2: ds.Object) bool {
    return o1.pos.roundX() < o2.pos.roundX() + o2.sprite.sizeX and
        o1.pos.roundX() + o1.sprite.sizeX > o2.pos.roundX() and
        o1.pos.roundY() < o2.pos.roundY() + o2.sprite.sizeY and
        o1.pos.roundY() + o1.sprite.sizeY > o2.pos.roundY();
}

pub fn areAnyEnemiesAlive() bool {
    return numEnemiesAlive > 0;
}

pub fn killPlayer() !void {
    playerDeathMarker = ds.DeathMarker{ .creationTime = std.time.microTimestamp(), .lifetime = 1e6, .obj = ds.Object{ .pos = player.?.pos, .sprite = spriteMap.get("playerDeath").? } };
    try registerObject(&playerDeathMarker.?.obj);
    try unregisterObject(player.?);
    player = null;
    lifes -= 1;
}

pub fn shootEnemy(index: u32) !void {
    var currentIndex: u32 = 0;
    for (enemies) |row| {
        for (row) |enemy| {
            if (enemy) |e| {
                if (currentIndex == index) {
                    try addProjectile(ds.Projectile{ .dir = -1, .obj = ds.Object{ .pos = .{ .x = e.pos.x, .y = e.pos.y }, .sprite = spriteMap.get("enemyProjectile").? } });
                    return;
                }
                currentIndex += 1;
            }
        }
    }
}

pub fn spawnBunkers(allocator: std.mem.Allocator) !void {
    for (0..bunkers.len) |i| {
        bunkers[i] = try ds.Bunker.init(ds.Position{ .x = @floatFromInt(blockSize + blockOffset + (i) * bunkerOffset), .y = 3 * (blockSize + blockOffset) }, spriteMap.get("bunker").?, allocator);
        for (&bunkers[i].?.parts) |*part| {
            if (part.*) |*p| {
                try registerObject(&p.obj);
            }
        }
    }
}

pub fn printScore(allocator: std.mem.Allocator) !void {
    const score = try std.fmt.allocPrint(allocator, "{s}{d}", .{ "score", points });
    drawText(score, 10, 242);
    allocator.free(score);
}

pub fn registerObject(obj: *ds.Object) !void {
    try objectList.append(obj);
    obj.index = spawnedObjects;
    spawnedObjects += 1;
}

pub fn unregisterObject(obj: ds.Object) !void {
    for (objectList.items, 0..) |o, i| {
        if (obj.index == o.index) {
            _ = objectList.swapRemove(i);
        }
    }
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    objectList = try std.ArrayList(*ds.Object).initCapacity(arena.allocator(), 100);

    const sheet = try zigimg.Image.fromFilePath(arena.allocator(), "SpriteSheet.png");
    spriteSheet = try arena.allocator().alloc(bool, sheet.width * sheet.height);
    spriteSheetW = @intCast(sheet.width);
    var it = sheet.iterator();
    while (it.next()) |px| {
        spriteSheet[it.current_index - 1] = px.r > 0 or px.b > 0 or px.g > 0;
    }
    spriteMap = try sprites.init(arena.allocator());

    w.createWindow(W, H, &buffer, 4);
    var deltaTime: f32 = 0;
    var enemyGoingLeft = false;
    var shootTime = std.time.microTimestamp();
    var lastEnemyMove = std.time.microTimestamp();
    var round: u32 = 0;
    var gameOver: bool = false;
    var shotCount: u32 = 0;
    var mysteryShipSpawn: bool = false;
    var worldStep: u32 = 0;

    try createEnemies(round);
    try respawnPlayer();
    try spawnBunkers(arena.allocator());

    var startTime = std.time.microTimestamp();
    while (w.tickWindow(&playerInput)) {
        w.redraw();
        clearBuffer();
        if (gameOver) {
            continue;
        }

        for (objectList.items) |o| {
            drawObject(o.*);
        }

        for (deathMarkers, 0..) |dm, i| {
            if (dm) |o| {
                if (std.time.microTimestamp() - o.creationTime > o.lifetime) {
                    try unregisterObject(o.obj);
                    deathMarkers[i] = null;
                }
            }
        }

        if (playerDeathMarker) |dm| {
            if (std.time.microTimestamp() - dm.creationTime > dm.lifetime) {
                try unregisterObject(dm.obj);
                playerDeathMarker = null;
                if (lifes > 0) {
                    try respawnPlayer();
                } else {
                    gameOver = true;
                }
            }
        }
        if (player) |p| {
            if (playerInput.left) {
                addPlayerX(-playerSpeed * deltaTime);
            } else if (playerInput.right) {
                addPlayerX(playerSpeed * deltaTime);
            } else if (playerInput.shoot and std.time.microTimestamp() - shootTime > shootCooldownMicro) {
                try addProjectile(ds.Projectile{ .obj = ds.Object{ .pos = .{ .x = p.pos.x + @as(f32, @floatFromInt(player.?.sprite.sizeX)) / 2, .y = p.pos.y + projectileSpawnDistance }, .sprite = spriteMap.get("playerProjectile").? }, .dir = 1 });
                shotCount += 1;
                mysteryShipSpawn = (shotCount % 23) == 0;
                shootTime = std.time.microTimestamp();
            }
        }
        if (mysteryShip) |s| {
            const newPos = s.pos.x + mysteryShipSpeed * deltaTime;
            if (newPos > W) {
                try unregisterObject(s);
                mysteryShip = null;
            } else {
                mysteryShip.?.pos.x = newPos;
            }
        } else if (mysteryShipSpawn) {
            try spawnMysteryShip();
            mysteryShipSpawn = false;
        }

        try printScore(arena.allocator());

        if (std.time.microTimestamp() - lastEnemyMove > worldStepTime) {
            worldStep += 1;
            for (objectList.items) |o| {
                o.stepAnim(worldStep);
            }
            lastEnemyMove = std.time.microTimestamp();
            try shootEnemy(rand.intRangeAtMost(u32, 0, numEnemiesAlive - 1));
            var reachedEnd: bool = false;
            if (enemyGoingLeft) {
                reachedEnd = addEnemyX(-enemyMoveDeltaX);
            } else {
                reachedEnd = addEnemyX(enemyMoveDeltaX);
            }
            if (reachedEnd) {
                std.debug.print("reached End", .{});
                gameOver = addEnemyY(-enemyMoveDeltaY);
                enemyGoingLeft = !enemyGoingLeft;
            }
        }
        try updateCollision();
        updateProjectiles(deltaTime);
        if (!areAnyEnemiesAlive()) {
            round += 1;
            worldStepTime = maxWorldStepTime;
            try createEnemies(round);
            enemyGoingLeft = false;
        }
        deltaTime = @floatFromInt(std.time.microTimestamp() - startTime);
        startTime = std.time.microTimestamp();
        // std.debug.print("delta time {d} \n", .{deltaTime});
    }
}
