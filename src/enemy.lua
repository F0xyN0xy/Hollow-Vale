Enemy              = {}
Enemy.__index      = Enemy

local CHASE_RANGE  = 200
local ATTACK_RANGE = 30

local CONFIGS      = {
    orc        = { speed = 60, hp = 3, damage = 1, attackCD = 1.0 },
    greenslime = { speed = 40, hp = 2, damage = 1, attackCD = 1.2 },
    redslime   = { speed = 55, hp = 1, damage = 1, attackCD = 0.9 },
    bat        = { speed = 80, hp = 1, damage = 1, attackCD = 0.8 },
}

function Enemy:new(kind, col, row)
    local e       = setmetatable({}, Enemy)
    e.kind        = kind
    local cfg     = CONFIGS[kind] or CONFIGS.orc
    local ts      = TILE_SIZE * SCALE

    e.x           = (col - 1) * ts
    e.y           = (row - 1) * ts
    e.hp          = cfg.hp
    e.maxHp       = cfg.hp
    e.speed       = cfg.speed * SCALE
    e.damage      = cfg.damage
    e.attackCD    = 0
    e.attackCDmax = cfg.attackCD

    e.dead        = false
    e.deathTimer  = 0
    e.hitFlash    = 0

    e.frame       = 1
    e.frameTime   = 0
    e.frameDur    = 0.22
    e.direction   = "down"

    local base    = "assets/Monster/"
    local dirs    = { "down", "up", "left", "right" }
    e.sprites     = {}
    for _, d in ipairs(dirs) do
        local ok1, i1 = pcall(love.graphics.newImage, base .. kind .. "_" .. d .. "_1.png")
        local ok2, i2 = pcall(love.graphics.newImage, base .. kind .. "_" .. d .. "_2.png")
        e.sprites[d] = { ok1 and i1 or nil, ok2 and i2 or nil }
    end

    local okH, sH = pcall(love.audio.newSource, "assets/Sound/hitmonster.wav", "static")
    e.hitSound = okH and sH or nil
    if e.hitSound then e.hitSound:setVolume(0.5) end

    return e
end

function Enemy:update(dt, player, world)
    if self.dead then
        self.deathTimer = self.deathTimer + dt
        return
    end

    local ts = TILE_SIZE * SCALE
    local px = player.x + ts / 2
    local py = player.y + ts / 2
    local ex = self.x + ts / 2
    local ey = self.y + ts / 2
    local dx = px - ex
    local dy = py - ey
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < CHASE_RANGE and dist > 2 then
        local nx = dx / dist
        local ny = dy / dist

        if math.abs(dx) > math.abs(dy) then
            self.direction = dx > 0 and "right" or "left"
        else
            self.direction = dy > 0 and "down" or "up"
        end

        local margin = 4
        local pw, ph = ts - margin * 2, ts - margin * 2
        local newX = self.x + nx * self.speed * dt
        local newY = self.y + ny * self.speed * dt
        if not world:isSolid(newX + margin, self.y + margin, pw, ph) then self.x = newX end
        if not world:isSolid(self.x + margin, newY + margin, pw, ph) then self.y = newY end
    end

    self.attackCD = math.max(0, self.attackCD - dt)
    if dist < ATTACK_RANGE and self.attackCD == 0 then
        player:takeDamage(self.damage)
        self.attackCD = self.attackCDmax
    end

    self.frameTime = self.frameTime + dt
    if self.frameTime >= self.frameDur then
        self.frameTime = 0
        self.frame = (self.frame == 1) and 2 or 1
    end

    self.hitFlash = math.max(0, self.hitFlash - dt * 4)
end

function Enemy:takeDamage(dmg)
    if self.dead then return end
    self.hp = self.hp - dmg
    self.hitFlash = 1.0
    if self.hitSound then
        self.hitSound:stop(); self.hitSound:play()
    end
    if self.hp <= 0 then
        self.dead = true
        self.deathTimer = 0
    end
end

function Enemy:canRemove()
    return self.dead and self.deathTimer > 0.5
end

function Enemy:draw()
    if self:canRemove() then return end

    local imgs = self.sprites[self.direction]
    if not imgs or not imgs[1] then imgs = self.sprites["down"] end
    local img = imgs and imgs[self.frame]
    if not img then return end

    local f = self.hitFlash
    local alpha = self.dead and 0.3 or 1
    love.graphics.setColor(1, 1 - f * 0.6, 1 - f * 0.6, alpha)
    love.graphics.draw(img, self.x, self.y, 0, SCALE, SCALE)
    love.graphics.setColor(1, 1, 1)

    if self.hp < self.maxHp and not self.dead then
        local ts = TILE_SIZE * SCALE
        local bw = ts - 8
        local bx = self.x + 4
        local by = self.y - 8
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", bx, by, bw, 4)
        love.graphics.setColor(0.85, 0.15, 0.15)
        love.graphics.rectangle("fill", bx, by, bw * (self.hp / self.maxHp), 4)
        love.graphics.setColor(1, 1, 1)
    end
end
