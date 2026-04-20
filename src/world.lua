World            = {}
World.__index    = World

local T          = {
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
World.T          = T

local SOLID      = {
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
local IS_WATER   = {
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

local CHUNK_SIZE = 16
local RENDER_PAD = 2

local Perlin     = {}
do
    local function fade(t) return t * t * t * (t * (t * 6 - 15) + 10) end
    local function lerp(a, b, t) return a + t * (b - a) end

    local function grad(hash, x, y)
        local h = hash % 4
        local u = h < 2 and x or y
        local v = h < 2 and y or x
        return ((h % 2 == 0) and u or -u) + ((math.floor(h / 2) % 2 == 0) and v or -v)
    end

    function Perlin.buildPerm(seed)
        local p = {}
        for i = 0, 255 do p[i] = i end
        math.randomseed(seed)
        for i = 255, 1, -1 do
            local j = math.random(0, i)
            p[i], p[j] = p[j], p[i]
        end
        local perm = {}
        for i = 0, 511 do perm[i] = p[i % 256] end
        return perm
    end

    function Perlin.noise(perm, x, y)
        local xi = math.floor(x) % 256
        local yi = math.floor(y) % 256
        local xf = x - math.floor(x)
        local yf = y - math.floor(y)
        local u  = fade(xf)
        local v  = fade(yf)

        local aa = perm[perm[xi] + yi]
        local ab = perm[perm[xi] + yi + 1]
        local ba = perm[perm[xi + 1] + yi]
        local bb = perm[perm[xi + 1] + yi + 1]

        return lerp(
            lerp(grad(aa, xf, yf), grad(ba, xf - 1, yf), u),
            lerp(grad(ab, xf, yf - 1), grad(bb, xf - 1, yf - 1), u),
            v
        )
    end

    function Perlin.octave(perm, x, y, octaves, persistence, lacunarity)
        local val  = 0
        local amp  = 1
        local freq = 1
        local maxV = 0
        for _ = 1, octaves do
            val  = val + Perlin.noise(perm, x * freq, y * freq) * amp
            maxV = maxV + amp
            amp  = amp * persistence
            freq = freq * lacunarity
        end
        return val / maxV
    end
end

local function rawTileAt(perm, tperm, col, row, worldSeed)
    local scale      = 0.045
    local n          = Perlin.octave(perm, col * scale, row * scale, 5, 0.55, 2.0)
    local h          = (n + 1) * 0.5

    local WORLD_EDGE = 200
    if col <= 1 or row <= 1 or col >= WORLD_EDGE or row >= WORLD_EDGE then
        return T.WALL
    end

    if h < 0.38 then return T.WATER end

    local tscale     = 0.12
    local tn         = Perlin.octave(tperm, col * tscale, row * tscale, 3, 0.6, 2.0)
    local treeChance = (h - 0.38) * 1.5
    if tn > (0.62 - treeChance * 0.18) then
        return T.TREE
    end

    local escale = 0.08
    local en     = Perlin.octave(perm, (col + 500) * escale, (row + 500) * escale, 2, 0.5, 2.0)
    if en > 0.35 and h > 0.55 then
        return T.EARTH
    end

    return T.GRASS
end

local function autotileChunk(chunk, chunkCol, chunkRow, getTile)
    local out   = {}
    local cs    = CHUNK_SIZE
    local baseC = (chunkCol - 1) * cs
    local baseR = (chunkRow - 1) * cs

    local function worldTile(c, r)
        local lc = c - baseC
        local lr = r - baseR
        if lc >= 1 and lc <= cs and lr >= 1 and lr <= cs then
            return chunk[lr][lc]
        end
        return getTile(c, r)
    end

    local function isPassable(c, r)
        local id = worldTile(c, r)
        return id ~= T.WALL and not IS_WATER[id]
    end

    for lr = 1, cs do
        out[lr] = {}
        for lc = 1, cs do
            local id = chunk[lr][lc]
            local wc = baseC + lc
            local wr = baseR + lr
            if IS_WATER[id] or id == T.WATER then
                local gN = isPassable(wc, wr - 1)
                local gS = isPassable(wc, wr + 1)
                local gE = isPassable(wc + 1, wr)
                local gW = isPassable(wc - 1, wr)
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
            out[lr][lc] = id
        end
    end
    return out
end

function World:new(seed)
    local w  = setmetatable({}, World)
    w.seed   = seed or math.random(1, 999999)
    w.chunks = {}
    w.chests = {}

    math.randomseed(w.seed)
    w.perm        = Perlin.buildPerm(w.seed)
    w.tperm       = Perlin.buildPerm(w.seed + 31337)

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

    for cy = 0, 3 do
        for cx = 0, 3 do
            w:_loadChunk(cx, cy)
        end
    end

    return w
end

function World:_rawTile(col, row)
    return rawTileAt(self.perm, self.tperm, col, row, self.seed)
end

local CHEST_ITEMS = { "potion_red", "sword_normal", "coin_bronze", "boots", "key" }

function World:_loadChunk(cx, cy)
    local key = cx .. "," .. cy
    if self.chunks[key] then return self.chunks[key] end

    local cs    = CHUNK_SIZE
    local baseC = cx * cs
    local baseR = cy * cs

    local raw   = {}
    for lr = 1, cs do
        raw[lr] = {}
        for lc = 1, cs do
            raw[lr][lc] = self:_rawTile(baseC + lc, baseR + lr)
        end
    end

    local function getTile(c, r) return self:_rawTile(c, r) end
    local tiles = autotileChunk(raw, cx + 1, cy + 1, getTile)
    local out = {}
    local function isPassable(c, r)
        local lc2 = c - baseC; local lr2 = r - baseR
        local id
        if lc2 >= 1 and lc2 <= cs and lr2 >= 1 and lr2 <= cs then
            id = raw[lr2][lc2]
        else
            id = self:_rawTile(c, r)
        end
        return id ~= T.WALL and not IS_WATER[id]
    end
    for lr = 1, cs do
        out[lr] = {}
        for lc = 1, cs do
            local id = raw[lr][lc]
            if IS_WATER[id] or id == T.WATER then
                local wc = baseC + lc; local wr = baseR + lr
                local gN = isPassable(wc, wr - 1)
                local gS = isPassable(wc, wr + 1)
                local gE = isPassable(wc + 1, wr)
                local gW = isPassable(wc - 1, wr)
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
            out[lr][lc] = id
        end
    end

    local chunkChests = {}
    math.randomseed(self.seed + cx * 73856093 + cy * 19349663)
    local numChests = (math.random() < 0.35) and math.random(1, 2) or 0
    local attempts  = 0
    local placed    = 0
    while placed < numChests and attempts < 200 do
        attempts = attempts + 1
        local lc = math.random(2, cs - 1)
        local lr = math.random(2, cs - 1)
        if out[lr][lc] == T.GRASS then
            local wc = baseC + lc
            local wr = baseR + lr
            local clash = false
            for _, ch in ipairs(chunkChests) do
                if math.abs(ch.col - wc) < 3 and math.abs(ch.row - wr) < 3 then
                    clash = true; break
                end
            end
            if not clash then
                local chest = {
                    col    = wc,
                    row    = wr,
                    item   = CHEST_ITEMS[math.random(#CHEST_ITEMS)],
                    opened = false,
                }
                table.insert(chunkChests, chest)
                table.insert(self.chests, chest)
                placed = placed + 1
            end
        end
    end

    local chunk = { tiles = out, chests = chunkChests }
    self.chunks[key] = chunk
    return chunk
end

function World:tileAt(col, row)
    local cs = CHUNK_SIZE
    local cx = math.floor((col - 1) / cs)
    local cy = math.floor((row - 1) / cs)
    local lc = (col - 1) % cs + 1
    local lr = (row - 1) % cs + 1
    local ch = self:_loadChunk(cx, cy)
    return ch.tiles[lr][lc]
end

function World:ensureChunks(camX, camY, sw, sh)
    local ts  = TILE_SIZE * SCALE
    local cs  = CHUNK_SIZE
    local csp = cs * ts
    local cx0 = math.floor(camX / csp) - RENDER_PAD
    local cy0 = math.floor(camY / csp) - RENDER_PAD
    local cx1 = math.floor((camX + sw) / csp) + RENDER_PAD
    local cy1 = math.floor((camY + sh) / csp) + RENDER_PAD
    for cy = cy0, cy1 do
        for cx = cx0, cx1 do
            if cx >= 0 and cy >= 0 then
                self:_loadChunk(cx, cy)
            end
        end
    end
end

function World:findSpawn()
    local ts = TILE_SIZE * SCALE
    for r = 5, 28 do
        for c = 5, 28 do
            if self:tileAt(c, r) == T.GRASS then
                return (c - 1) * ts, (r - 1) * ts
            end
        end
    end
    return 5 * ts, 5 * ts
end

function World:isSolid(px, py, pw, ph)
    local ts = TILE_SIZE * SCALE
    local c1 = math.floor(px / ts) + 1
    local r1 = math.floor(py / ts) + 1
    local c2 = math.floor((px + pw - 1) / ts) + 1
    local r2 = math.floor((py + ph - 1) / ts) + 1
    for r = r1, r2 do
        for c = c1, c2 do
            if c >= 1 and r >= 1 then
                local id = self:tileAt(c, r)
                if SOLID[id] then return true end
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
            local cx   = (ch.col - 1) * ts + ts / 2
            local cy   = (ch.row - 1) * ts + ts / 2
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
    local sw, sh = love.graphics.getDimensions()
    local ts     = TILE_SIZE * SCALE
    local cs     = CHUNK_SIZE

    self:ensureChunks(camera.x, camera.y, sw, sh)

    local startCol = math.max(1, math.floor(camera.x / ts))
    local startRow = math.max(1, math.floor(camera.y / ts))
    local endCol   = math.floor((camera.x + sw) / ts) + 2
    local endRow   = math.floor((camera.y + sh) / ts) + 2

    for r = startRow, endRow do
        for c = startCol, endCol do
            local id  = self:tileAt(c, r)
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
