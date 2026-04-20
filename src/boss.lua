Boss = {}
Boss.__index = Boss

local Fireball = {}
Fireball.__index = Fireball

function Fireball:new(x, y, dx, dy, sprites)
    local f      = setmetatable({}, Fireball)
    f.x, f.y     = x, y
    f.dx, f.dy   = dx, dy
    f.sprites    = sprites
    f.frame      = 1
    f.frameTime  = 0
    f.frameDur   = 0.12
    f.dead       = false
    local ax, ay = math.abs(dx), math.abs(dy)
    if ax > ay then
        f.dir = dx > 0 and "right" or "left"
    else
        f.dir = dy > 0 and "down" or "up"
    end
    return f
end

function Fireball:update(dt, world, player)
    if self.dead then return end
    local ts = TILE_SIZE * SCALE
    self.x = self.x + self.dx * dt
    self.y = self.y + self.dy * dt

    if world:isSolid(self.x, self.y, ts * 0.5, ts * 0.5) then
        self.dead = true; return
    end
    if self.x < 0 or self.x > world.cols * ts or
        self.y < 0 or self.y > world.rows * ts then
        self.dead = true; return
    end
    local px, py = player.x + ts * 0.2, player.y + ts * 0.2
    local pw, ph = ts * 0.6, ts * 0.6
    if self.x < px + pw and self.x + ts * 0.5 > px and
        self.y < py + ph and self.y + ts * 0.5 > py then
        player:takeDamage(1)
        self.dead = true; return
    end
    self.frameTime = self.frameTime + dt
    if self.frameTime >= self.frameDur then
        self.frameTime = 0
        self.frame = (self.frame == 1) and 2 or 1
    end
end

function Fireball:draw()
    if self.dead then return end
    local imgs = self.sprites[self.dir]
    local img  = imgs and imgs[self.frame]
    if img then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(img, self.x, self.y, 0, SCALE, SCALE)
    end
end

local PHASE1_HP    = 10
local PHASE2_BONUS = 8

local ST           = { IDLE = "idle", CHASE = "chase", ATTACK = "attack", CAST = "cast", TRANSITION = "transition", DEAD =
"dead" }

function Boss:new(col, row)
    local b          = setmetatable({}, Boss)
    local ts         = TILE_SIZE * SCALE

    b.x              = (col - 1) * ts
    b.y              = (row - 1) * ts
    b.speed          = 55 * SCALE

    b.maxHp          = PHASE1_HP + PHASE2_BONUS
    b.hp             = b.maxHp
    b.phase          = 1

    b.state          = ST.IDLE
    b.stateTimer     = 0
    b.direction      = "down"

    b.hitFlash       = 0
    b.dead           = false
    b.deathTimer     = 0

    b.transFlash     = 0

    b.attackCooldown = 0
    b.castCooldown   = 0
    b.fireballs      = {}

    b.frame          = 1
    b.frameTime      = 0
    b.frameDur       = 0.2
    b.attacking      = false
    b.attackTimer    = 0

    local base       = "assets/Monster/"
    local dirs       = { "down", "up", "left", "right" }
    b.walkSprites    = {}
    b.attackSprites  = {}
    b.p2WalkSprites  = {}
    b.p2AtkSprites   = {}

    for _, d in ipairs(dirs) do
        local function load2(prefix, dir)
            local ok1, i1 = pcall(love.graphics.newImage, base .. prefix .. dir .. "_1.png")
            local ok2, i2 = pcall(love.graphics.newImage, base .. prefix .. dir .. "_2.png")
            return { ok1 and i1 or nil, ok2 and i2 or nil }
        end
        b.walkSprites[d]   = load2("skeletonlord_", d)
        b.attackSprites[d] = load2("skeletonlord_attack_", d)
        b.p2WalkSprites[d] = load2("skeletonlord_phase2_", d)
        b.p2AtkSprites[d]  = load2("skeletonlord_phase2_attack_", d)
    end

    local pb = "assets/Projectile/"
    b.fbSprites = {}
    for _, d in ipairs(dirs) do
        local ok1, i1 = pcall(love.graphics.newImage, pb .. "fireball_" .. d .. "_1.png")
        local ok2, i2 = pcall(love.graphics.newImage, pb .. "fireball_" .. d .. "_2.png")
        b.fbSprites[d] = { ok1 and i1 or nil, ok2 and i2 or nil }
    end

    local function loadSnd(f, vol)
        local ok, s = pcall(love.audio.newSource, "assets/Sound/" .. f, "static")
        if ok then s:setVolume(vol or 0.5) end
        return ok and s or nil
    end
    b.hitSound   = loadSnd("hitmonster.wav", 0.6)
    b.castSound  = loadSnd("burning.wav", 0.5)
    b.transSound = loadSnd("powerup.wav", 0.7)
    b.deathSound = loadSnd("fanfare.wav", 0.8)
    b.bossMusic  = nil

    return b
end

function Boss:startFightMusic()
    if self.bossMusic then return end
    local ok, bgm = pcall(love.audio.newSource, "assets/Sound/FinalBattle.wav", "stream")
    if ok then
        bgm:setLooping(true); bgm:setVolume(0.55); bgm:play()
        self.bossMusic = bgm
    end
end

function Boss:stopFightMusic()
    if self.bossMusic then
        self.bossMusic:stop(); self.bossMusic = nil
    end
end

function Boss:getAttackBox()
    if not self.attacking then return nil end
    local ts    = TILE_SIZE * SCALE * 2
    local reach = ts * 0.8
    local thick = ts * 0.6
    local cx    = self.x + ts / 2
    local cy    = self.y + ts / 2
    local d     = self.direction
    if d == "right" then return { x = cx, y = cy - thick / 2, w = reach, h = thick } end
    if d == "left" then return { x = cx - reach, y = cy - thick / 2, w = reach, h = thick } end
    if d == "down" then return { x = cx - thick / 2, y = cy, w = thick, h = reach } end
    if d == "up" then return { x = cx - thick / 2, y = cy - reach, w = thick, h = reach } end
end

function Boss:update(dt, player, world)
    if self.dead then
        self.deathTimer = self.deathTimer + dt
        return
    end

    local ts   = TILE_SIZE * SCALE * 2
    local cx   = self.x + ts / 2
    local cy   = self.y + ts / 2
    local pcx  = player.x + TILE_SIZE * SCALE / 2
    local pcy  = player.y + TILE_SIZE * SCALE / 2
    local dx   = pcx - cx
    local dy   = pcy - cy
    local dist = math.sqrt(dx * dx + dy * dy)

    if math.abs(dx) > math.abs(dy) then
        self.direction = dx > 0 and "right" or "left"
    else
        self.direction = dy > 0 and "down" or "up"
    end

    local threshold = math.floor(b.maxHp * 0.4)
    if self.phase == 1 and self.hp <= math.floor(self.maxHp * 0.4)
        and self.state ~= ST.TRANSITION then
        self.state      = ST.TRANSITION
        self.stateTimer = 1.5
        self.transFlash = 1.5
        if self.transSound then
            self.transSound:stop(); self.transSound:play()
        end
        self.hp = math.min(self.maxHp, self.hp + 4)
    end

    self.stateTimer = math.max(0, self.stateTimer - dt)

    if self.state == ST.TRANSITION then
        if self.stateTimer == 0 then
            self.phase = 2
            self.speed = 70 * SCALE
            self.state = ST.CHASE
        end
    elseif self.state == ST.IDLE then
        if dist < 350 then
            self.state = ST.CHASE
            self:startFightMusic()
        end
    elseif self.state == ST.CHASE then
        if dist > 4 then
            local nx = dx / dist; local ny = dy / dist
            local spd = self.speed
            local margin = 6
            local bts = TILE_SIZE * SCALE
            local newX = self.x + nx * spd * dt
            local newY = self.y + ny * spd * dt
            if not world:isSolid(newX + margin, self.y + margin, bts - margin * 2, bts - margin * 2) then
                self.x = newX
            end
            if not world:isSolid(self.x + margin, newY + margin, bts - margin * 2, bts - margin * 2) then
                self.y = newY
            end
        end

        self.attackCooldown = math.max(0, self.attackCooldown - dt)
        self.castCooldown   = math.max(0, self.castCooldown - dt)

        if dist < 80 and self.attackCooldown == 0 then
            self.state          = ST.ATTACK
            self.stateTimer     = 0.4
            self.attacking      = true
            self.attackTimer    = 0
            self.attackCooldown = self.phase == 1 and 1.8 or 1.2
        elseif dist < 300 and self.castCooldown == 0 then
            self.state        = ST.CAST
            self.stateTimer   = 0.5
            self.castCooldown = self.phase == 1 and 2.5 or 1.6
        end
    elseif self.state == ST.ATTACK then
        if self.stateTimer == 0 then
            self.attacking = false
            self.state     = ST.CHASE
        end
    elseif self.state == ST.CAST then
        if self.stateTimer == 0 then
            self:spawnFireballs(pcx, pcy)
            self.state = ST.CHASE
        end
    end

    if self.attacking then
        self.attackTimer = self.attackTimer + dt
        if self.attackTimer >= 0.4 then
            self.attacking = false; self.attackTimer = 0
        end
    end

    for i = #self.fireballs, 1, -1 do
        local fb = self.fireballs[i]
        fb:update(dt, world, player)
        if fb.dead then table.remove(self.fireballs, i) end
    end

    self.frameTime = self.frameTime + dt
    if self.frameTime >= self.frameDur then
        self.frameTime = 0
        self.frame = (self.frame == 1) and 2 or 1
    end

    self.hitFlash   = math.max(0, self.hitFlash - dt * 3)
    self.transFlash = math.max(0, self.transFlash - dt)
end

function Boss:spawnFireballs(tx, ty)
    if self.castSound then
        self.castSound:stop(); self.castSound:play()
    end
    local ts  = TILE_SIZE * SCALE
    local cx  = self.x + ts
    local cy  = self.y + ts
    local spd = 180 * SCALE

    if self.phase == 1 then
        local dx = tx - cx; local dy = ty - cy
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0 then
            table.insert(self.fireballs, Fireball:new(cx, cy,
                dx / len * spd, dy / len * spd, self.fbSprites))
        end
    else
        local angles = { 0, math.pi / 2, math.pi, math.pi * 1.5 }
        for _, a in ipairs(angles) do
            table.insert(self.fireballs, Fireball:new(cx, cy,
                math.cos(a) * spd, math.sin(a) * spd, self.fbSprites))
        end
        local dx = tx - cx; local dy = ty - cy
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0 then
            table.insert(self.fireballs, Fireball:new(cx, cy,
                dx / len * spd, dy / len * spd, self.fbSprites))
        end
    end
end

function Boss:takeDamage(dmg)
    if self.dead or self.state == ST.TRANSITION then return end
    self.hp = self.hp - dmg
    self.hitFlash = 1.0
    if self.hitSound then
        self.hitSound:stop(); self.hitSound:play()
    end
    if self.hp <= 0 then
        self.hp         = 0
        self.dead       = true
        self.deathTimer = 0
        self:stopFightMusic()
        if self.deathSound then
            self.deathSound:stop(); self.deathSound:play()
        end
    end
end

function Boss:canRemove()
    return self.dead and self.deathTimer > 2.0
end

function Boss:draw()
    local ts = TILE_SIZE * SCALE

    for _, fb in ipairs(self.fireballs) do fb:draw() end

    if self:canRemove() then return end

    local walkSet = self.phase == 2 and self.p2WalkSprites or self.walkSprites
    local atkSet  = self.phase == 2 and self.p2AtkSprites or self.attackSprites
    local sprites = self.attacking and atkSet or walkSet

    local imgs    = sprites[self.direction]
    local img     = imgs and imgs[self.frame]
    if not img then return end

    local ox, oy = 0, 0
    if self.attacking then
        if self.direction == "up" then oy = -ts * 2 end
        if self.direction == "left" then ox = -ts * 2 end
    end

    local f = self.hitFlash
    local tf = self.transFlash
    local alpha = self.dead and math.max(0, 1 - self.deathTimer) or 1

    if tf > 0 then
        love.graphics.setColor(1, 0.6 + tf * 0.4, tf, alpha)
    else
        love.graphics.setColor(1, 1 - f * 0.7, 1 - f * 0.7, alpha)
    end

    love.graphics.draw(img, self.x + ox, self.y + oy, 0, SCALE * 2, SCALE * 2)
    love.graphics.setColor(1, 1, 1)
end

function Boss:drawHUD()
    if self.state == ST.IDLE or self:canRemove() then return end

    local sw = love.graphics.getWidth()
    local bw = math.floor(sw * 0.5)
    local bh = 14
    local bx = math.floor((sw - bw) / 2)
    local by = love.graphics.getHeight() - 40

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", bx - 2, by - 16, bw + 4, bh + 20, 4, 4)

    love.graphics.setColor(0.85, 0.75, 0.4)
    local label = self.phase == 2 and "Skeleton Lord  [ phase II ]" or "Skeleton Lord"
    love.graphics.print(label, bx, by - 14)

    love.graphics.setColor(0.25, 0.1, 0.1)
    love.graphics.rectangle("fill", bx, by, bw, bh, 3, 3)

    local pct = math.max(0, self.hp / self.maxHp)
    local barColor = self.phase == 2 and { 0.7, 0.2, 0.9 } or { 0.75, 0.15, 0.15 }
    love.graphics.setColor(barColor)
    love.graphics.rectangle("fill", bx, by, math.floor(bw * pct), bh, 3, 3)

    local threshX = bx + math.floor(bw * (PHASE2_BONUS / (PHASE1_HP + PHASE2_BONUS)))
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.rectangle("fill", threshX - 1, by, 2, bh)

    love.graphics.setColor(1, 1, 1)
end