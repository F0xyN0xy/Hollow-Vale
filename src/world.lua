World = {}
World.__index = World

local T = {
    GRASS    = 1,
    EARTH    = 2,
    WALL     = 3,
    TREE     = 4,
    WATER    = 10,
    WATER_N  = 11,
    WATER_S  = 12,
    WATER_E  = 13,
    WATER_W  = 14,
    WATER_NE = 15,
    WATER_NW = 16,
    WATER_SE = 17,
    WATER_SW = 18,
}
World.T = T

local SOLID = {
    [T.WALL] = true,
    [T.TREE] = true,
    [T.WATER] = true,
    [T.WATER_N] = true,
    [T.WATER_S] = true,
    [T.WATER_E] = true,
    [T.WATER_W] = true,
    [T.WATER_NE] = true,
    [T.WATER_NW] = true,
    [T.WATER_SE] = true,
    [T.WATER_SW] = true,
}

local IS_WATER = {
    [T.WATER] = true,
    [T.WATER_N] = true,
    [T.WATER_S] = true,
    [T.WATER_E] = true,
    [T.WATER_W] = true,
    [T.WATER_NE] = true,
    [T.WATER_NW] = true,
    [T.WATER_SE] = true,
    [T.WATER_SW] = true,
}

local COLS = 40
local ROWS = 30

local function lerp(a, b, t) return a + (t * t * (3 - 2 * t)) * (b - a) end

local function hash(n)
    n = math.abs(math.floor(n)) % 2147483647
    n = (n * 1664525 + 1013904223) % 2147483648
    n = (n * 22695477 + 1) % 2147483648
    return n / 2147483648
end

local function noise2d(x, y, seed)
    local s   = seed or 0
    local ix  = math.floor(x); local iy = math.floor(y)
    local fx  = x - ix; local fy = y - iy
    local v00 = hash(ix + iy * 57 + s)
    local v10 = hash(ix + 1 + iy * 57 + s)
    local v01 = hash(ix + (iy + 1) * 57 + s)
    local v11 = hash(ix + 1 + (iy + 1) * 57 + s)
    return lerp(lerp(v00, v10, fx), lerp(v01, v11, fx), fy)
end

local function generateBase(seed)
    local map = {}
    for r = 1, ROWS do
        map[r] = {}
        for c = 1, COLS do
            local n = noise2d(c * 0.18, r * 0.18, seed)
            map[r][c] = (n < 0.38) and T.WATER or T.GRASS
        end
    end
    for r = 1, ROWS do
        map[r][1] = T.WALL; map[r][COLS] = T.WALL
    end
    for c = 1, COLS do
        map[1][c] = T.WALL; map[ROWS][c] = T.WALL
    end
    return map
end

local function isGrass(map, r, c)
    if r < 1 or r > ROWS or c < 1 or c > COLS then return true end
    return not IS_WATER[map[r][c]] and map[r][c] ~= T.WALL
end

local function autotileWater(map)
    local out = {}
    for r = 1, ROWS do
        out[r] = {}
        for c = 1, COLS do
            local id = map[r][c]
            if id == T.WATER then
                local gN = isGrass(map, r - 1, c)
                local gS = isGrass(map, r + 1, c)
                local gE = isGrass(map, r, c + 1)
                local gW = isGrass(map, r, c - 1)
                if gN and gE then
                    id = T.WATER_NE
                elseif gN and gW then
                    id = T.WATER_NW
                elseif gS and gE then
                    id = T.WATER_SE
                elseif gS and gW then
                    id = T.WATER_SW
                elseif gN then
                    id = T.WATER_N
                elseif gS then
                    id = T.WATER_S
                elseif gE then
                    id = T.WATER_E
                elseif gW then
                    id = T.WATER_W
                end
            end
            out[r][c] = id
        end
    end
    return out
end

local function scatterTrees(map, seed)
    math.randomseed(seed + 9999)
    for r = 2, ROWS - 1 do
        for c = 2, COLS - 1 do
            if map[r][c] == T.GRASS then
                local ok = true
                for dr = -1, 1 do
                    for dc = -1, 1 do
                        local row = map[r + dr]
                        if row and IS_WATER[row[c + dc]] then ok = false end
                    end
                end
                if ok and math.random() < 0.06 then
                    map[r][c] = T.TREE
                end
            end
        end
    end
end

local function placeChests(map, seed, count)
    math.randomseed(seed + 1234)
    local chests   = {}
    local items    = { "potion_red", "sword_normal", "coin_bronze", "boots", "key" }
    local attempts = 0
    while #chests < count and attempts < 2000 do
        attempts = attempts + 1
        local c = math.random(3, COLS - 2)
        local r = math.random(3, ROWS - 2)
        if map[r][c] == T.GRASS then
            local clash = false
            for _, ch in ipairs(chests) do
                if math.abs(ch.col - c) < 3 and math.abs(ch.row - r) < 3 then
                    clash = true; break
                end
            end
            if not clash then
                table.insert(chests, {
                    col = c,
                    row = r,
                    item = items[math.random(#items)],
                    opened = false
                })
            end
        end
    end
    return chests
end

function World:new(seed)
    local w    = setmetatable({}, World)
    w.seed     = seed or math.random(1, 99999)
    w.rows     = ROWS
    w.cols     = COLS

    local base = generateBase(w.seed)
    scatterTrees(base, w.seed)
    w.map         = autotileWater(base)
    w.chests      = placeChests(w.map, w.seed, 8)

    local nv      = "assets/Environment/"
    local ob      = "assets/Object/"

    w.tiles       = {
        [T.GRASS]    = love.graphics.newImage(nv .. "grass00.png"),
        [T.EARTH]    = love.graphics.newImage(nv .. "earth.png"),
        [T.WALL]     = love.graphics.newImage(nv .. "wall.png"),
        [T.TREE]     = love.graphics.newImage(nv .. "tree.png"),
        [T.WATER]    = love.graphics.newImage(nv .. "water00.png"),
        [T.WATER_N]  = love.graphics.newImage(nv .. "water03.png"),
        [T.WATER_S]  = love.graphics.newImage(nv .. "water08.png"),
        [T.WATER_E]  = love.graphics.newImage(nv .. "water06.png"),
        [T.WATER_W]  = love.graphics.newImage(nv .. "water05.png"),
        [T.WATER_NE] = love.graphics.newImage(nv .. "water04.png"),
        [T.WATER_NW] = love.graphics.newImage(nv .. "water02.png"),
        [T.WATER_SE] = love.graphics.newImage(nv .. "water09.png"),
        [T.WATER_SW] = love.graphics.newImage(nv .. "water07.png"),
    }
    w.waterRipple = love.graphics.newImage(nv .. "water01.png")

    w.chestClosed = love.graphics.newImage(ob .. "chest.png")
    w.chestOpened = love.graphics.newImage(ob .. "chest_opened.png")

    w.itemSprites = {}
    for _, name in ipairs({ "potion_red", "sword_normal", "coin_bronze",
        "boots", "key", "axe", "shield_blue", "lantern" }) do
        local ok, img = pcall(love.graphics.newImage, ob .. name .. ".png")
        if ok then w.itemSprites[name] = img end
    end

    local ok, snd = pcall(love.audio.newSource, "assets/Sound/coin.wav", "static")
    w.pickupSound = ok and snd or nil
    if w.pickupSound then w.pickupSound:setVolume(0.5) end

    w.waterTimer = 0
    w.waterFrame = 1

    return w
end

function World:findSpawn()
    local ts = TILE_SIZE * SCALE
    for r = 3, self.rows - 3 do
        for c = 3, self.cols - 3 do
            if self.map[r][c] == T.GRASS then
                return (c - 1) * ts, (r - 1) * ts
            end
        end
    end
    return 3 * ts, 3 * ts
end

function World:isSolid(px, py, pw, ph)
    local ts = TILE_SIZE * SCALE
    local c1 = math.floor(px / ts) + 1
    local r1 = math.floor(py / ts) + 1
    local c2 = math.floor((px + pw - 1) / ts) + 1
    local r2 = math.floor((py + ph - 1) / ts) + 1
    for r = r1, r2 do
        for c = c1, c2 do
            if r >= 1 and r <= self.rows and c >= 1 and c <= self.cols then
                if SOLID[self.map[r][c]] then return true end
            end
        end
    end
    return false
end

function World:tryOpenChest(player)
    local ts = TILE_SIZE * SCALE
    local px = player.x + ts / 2
    local py = player.y + ts / 2
    for _, ch in ipairs(self.chests) do
        if not ch.opened then
            local cx = (ch.col - 1) * ts + ts / 2
            local cy = (ch.row - 1) * ts + ts / 2
            local dist = math.sqrt((px - cx) ^ 2 + (py - cy) ^ 2)
            if dist < ts * 1.2 then
                ch.opened = true
                if self.pickupSound then
                    self.pickupSound:stop(); self.pickupSound:play()
                end
                return ch.item
            end
        end
    end
    return nil
end

function World:update(dt)
    self.waterTimer = self.waterTimer + dt
    if self.waterTimer > 0.6 then
        self.waterTimer = 0
        self.waterFrame = (self.waterFrame == 1) and 2 or 1
    end
end

function World:draw(camera)
    local sw, sh   = love.graphics.getDimensions()
    local ts       = TILE_SIZE * SCALE

    local startCol = math.max(1, math.floor(camera.x / ts))
    local startRow = math.max(1, math.floor(camera.y / ts))
    local endCol   = math.min(self.cols, math.ceil((camera.x + sw) / ts) + 1)
    local endRow   = math.min(self.rows, math.ceil((camera.y + sh) / ts) + 1)

    for r = startRow, endRow do
        for c = startCol, endCol do
            local id  = self.map[r][c]
            local img = self.tiles[id]
            if id == T.WATER then
                img = (self.waterFrame == 1) and self.tiles[T.WATER] or self.waterRipple
            end
            if img then
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(img, (c - 1) * ts, (r - 1) * ts, 0, SCALE, SCALE)
            end
        end
    end

    for _, ch in ipairs(self.chests) do
        local cx = (ch.col - 1) * ts
        local cy = (ch.row - 1) * ts
        if cx > camera.x - ts and cx < camera.x + sw + ts and
            cy > camera.y - ts and cy < camera.y + sh + ts then
            local img = ch.opened and self.chestOpened or self.chestClosed
            if img then
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(img, cx, cy, 0, SCALE, SCALE)
            end
        end
    end
end
