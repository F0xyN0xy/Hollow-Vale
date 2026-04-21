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

local Particle = {}
Particle.__index = Particle

function Particle:new(x, y, r, g, b, size, vx, vy, life)
    local p = setmetatable({}, Particle)
    p.x, p.y = x, y
    p.r, p.g, p.b = r, g, b
    p.size = size or 4
    p.vx, p.vy = vx or 0, vy or 0
    p.life = life or 0.6
    p.maxLife = p.life
    p.dead = false
    return p
end

function Particle:update(dt)
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    self.vy = self.vy + 120 * dt
    self.life = self.life - dt
    if self.life <= 0 then self.dead = true end
end

function Particle:draw()
    if self.dead then return end
    local a = math.max(0, self.life / self.maxLife)
    local s = self.size * a
    love.graphics.setColor(self.r, self.g, self.b, a)
    love.graphics.rectangle("fill", self.x - s / 2, self.y - s / 2, s, s)
end

local PHASE1_HP    = 10
local PHASE2_BONUS = 8

local ST           = {
    IDLE       = "idle",
    CHASE      = "chase",
    ATTACK     = "attack",
    CAST       = "cast",
    CHARGE     = "charge",
    TRANSITION = "transition",
    DEAD       = "dead",
}

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
    b.chargeCooldown = 0
    b.fireballs      = {}
    b.particles      = {}

    b.charging       = false
    b.chargeDx       = 0
    b.chargeDy       = 0
    b.chargeSpeed    = 0
    b.chargeTimer    = 0

    b.enrageTimer    = 0
    b.enraged        = false

    b.screenShake    = 0

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
    b.hitSound    = loadSnd("hitmonster.wav", 0.6)
    b.castSound   = loadSnd("burning.wav", 0.5)
    b.transSound  = loadSnd("powerup.wav", 0.7)
    b.deathSound  = loadSnd("fanfare.wav", 0.8)
    b.chargeSound = loadSnd("hitmonster.wav", 0.4)
    b.bossMusic   = nil

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

function Boss:spawnDeathParticles()
    local ts = TILE_SIZE * SCALE
    local cx = self.x + ts
    local cy = self.y + ts
    for _ = 1, 60 do
        local angle = math.random() * math.pi * 2
        local speed = math.random(40, 220)
        local size  = math.random(3, 10)
        local life  = math.random(5, 14) / 10
        local r     = self.phase == 2 and 0.7 or 0.8
        local g     = self.phase == 2 and 0.1 or 0.8
        local b     = self.phase == 2 and 0.9 or 0.2
        table.insert(self.particles, Particle:new(
            cx + math.random(-ts, ts),
            cy + math.random(-ts, ts),
            r, g, b, size,
            math.cos(angle) * speed,
            math.sin(angle) * speed - 60,
            life
        ))
    end
end

function Boss:spawnHitParticles()
    local ts = TILE_SIZE * SCALE
    local cx = self.x + ts + math.random(-ts / 2, ts / 2)
    local cy = self.y + ts / 2
    for _ = 1, 5 do
        local angle = math.random() * math.pi * 2
        local speed = math.random(30, 100)
        table.insert(self.particles, Particle:new(
            cx, cy, 1, 0.5, 0.1, math.random(2, 5),
            math.cos(angle) * speed, math.sin(angle) * speed - 40,
            0.3 + math.random() * 0.2
        ))
    end
end

function Boss:startCharge(dx, dy, dist)
    self.state          = ST.CHARGE
    self.stateTimer     = 0.55
    self.charging       = false
    self.chargeDx       = dx / dist
    self.chargeDy       = dy / dist
    self.chargeSpeed    = (self.phase == 2 and 550 or 380) * SCALE
    self.chargeTimer    = 0
    self.chargeCooldown = self.phase == 2 and 5.0 or 7.0
    local ts            = TILE_SIZE * SCALE
    local cx            = self.x + ts
    local cy            = self.y + ts
    for _ = 1, 12 do
        local a = math.random() * math.pi * 2
        table.insert(self.particles, Particle:new(
            cx, cy,
            self.phase == 2 and 0.7 or 1,
            self.phase == 2 and 0.1 or 0.6,
            self.phase == 2 and 1.0 or 0.0,
            6, math.cos(a) * 60, math.sin(a) * 60 - 30, 0.5
        ))
    end
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
        local dx  = tx - cx
        local dy  = ty - cy
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0 then
            table.insert(self.fireballs, Fireball:new(cx, cy,
                dx / len * spd, dy / len * spd, self.fbSprites))
        end
    else
        local angles = { 0, math.pi / 2, math.pi, math.pi * 1.5 }
        if self.enraged then
            angles = { 0, math.pi / 4, math.pi / 2, math.pi * 0.75,
                math.pi, math.pi * 1.25, math.pi * 1.5, math.pi * 1.75 }
        end
        for _, a in ipairs(angles) do
            table.insert(self.fireballs, Fireball:new(cx, cy,
                math.cos(a) * spd, math.sin(a) * spd, self.fbSprites))
        end
        local dx  = tx - cx
        local dy  = ty - cy
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0 then
            table.insert(self.fireballs, Fireball:new(cx, cy,
                dx / len * spd, dy / len * spd, self.fbSprites))
        end
    end
end

function Boss:update(dt, player, world)
    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p:update(dt)
        if p.dead then table.remove(self.particles, i) end
    end

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

    if self.phase == 1 and self.hp <= math.floor(self.maxHp * 0.4)
        and self.state ~= ST.TRANSITION then
        self.state       = ST.TRANSITION
        self.stateTimer  = 1.5
        self.transFlash  = 1.5
        self.screenShake = 0.6
        if self.transSound then
            self.transSound:stop(); self.transSound:play()
        end
        self.hp = math.min(self.maxHp, self.hp + 4)
        self:spawnDeathParticles()
    end

    if self.phase == 2 and not self.enraged then
        self.enrageTimer = self.enrageTimer + dt
        if self.enrageTimer > 30 then
            self.enraged     = true
            self.speed       = 90 * SCALE
            self.screenShake = 0.8
            self:spawnDeathParticles()
        end
    end

    self.screenShake = math.max(0, self.screenShake - dt * 2)

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
            local nx     = dx / dist
            local ny     = dy / dist
            local spd    = self.speed
            local margin = 6
            local bts    = TILE_SIZE * SCALE
            local newX   = self.x + nx * spd * dt
            local newY   = self.y + ny * spd * dt
            if not world:isSolid(newX + margin, self.y + margin, bts - margin * 2, bts - margin * 2) then
                self.x = newX
            end
            if not world:isSolid(self.x + margin, newY + margin, bts - margin * 2, bts - margin * 2) then
                self.y = newY
            end
        end

        self.attackCooldown = math.max(0, self.attackCooldown - dt)
        self.castCooldown   = math.max(0, self.castCooldown - dt)
        self.chargeCooldown = math.max(0, self.chargeCooldown - dt)

        local atkRange      = 80
        local castRange     = 300
        local chgRange      = 250

        if dist < atkRange and self.attackCooldown == 0 then
            self.state          = ST.ATTACK
            self.stateTimer     = 0.4
            self.attacking      = true
            self.attackTimer    = 0
            self.attackCooldown = self.phase == 1 and 1.8 or (self.enraged and 0.8 or 1.2)
        elseif dist > atkRange and dist < chgRange and self.chargeCooldown == 0 then
            self:startCharge(dx, dy, dist)
        elseif dist < castRange and self.castCooldown == 0 then
            self.state        = ST.CAST
            self.stateTimer   = 0.5
            self.castCooldown = self.phase == 1 and 2.5 or (self.enraged and 1.0 or 1.6)
        end
    elseif self.state == ST.CHARGE then
        self.stateTimer = math.max(0, self.stateTimer - dt)
        if self.stateTimer > 0.25 then
        else
            self.charging = true
            local spd = self.chargeSpeed
            local bts = TILE_SIZE * SCALE
            local margin = 6
            local newX = self.x + self.chargeDx * spd * dt
            local newY = self.y + self.chargeDy * spd * dt
            local hitWall = false
            if world:isSolid(newX + margin, self.y + margin, bts - margin * 2, bts - margin * 2) then
                hitWall = true
            else
                self.x = newX
            end
            if world:isSolid(self.x + margin, newY + margin, bts - margin * 2, bts - margin * 2) then
                hitWall = true
            else
                self.y = newY
            end

            if math.random() < 0.4 then
                local ts2 = TILE_SIZE * SCALE
                table.insert(self.particles, Particle:new(
                    self.x + ts2 + math.random(-8, 8),
                    self.y + ts2 + math.random(-8, 8),
                    self.phase == 2 and 0.6 or 1,
                    self.phase == 2 and 0.2 or 0.8,
                    self.phase == 2 and 0.9 or 0.1,
                    math.random(3, 7), 0, 0, 0.25
                ))
            end

            local ts2 = TILE_SIZE * SCALE
            local px2, py2 = player.x + ts2 * 0.1, player.y + ts2 * 0.1
            local pw2, ph2 = ts2 * 0.8, ts2 * 0.8
            if self.x < px2 + pw2 and self.x + ts2 > px2 and
                self.y < py2 + ph2 and self.y + ts2 > py2 then
                player:takeDamage(2)
                hitWall = true
            end

            if hitWall or self.stateTimer == 0 then
                self.charging    = false
                self.state       = ST.CHASE
                self.screenShake = 0.25
                if self.chargeSound then
                    self.chargeSound:stop(); self.chargeSound:play()
                end
            end
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

function Boss:takeDamage(dmg)
    if self.dead or self.state == ST.TRANSITION then return end
    self.hp = self.hp - dmg
    self.hitFlash = 1.0
    if self.hitSound then
        self.hitSound:stop(); self.hitSound:play()
    end
    self:spawnHitParticles()
    if self.hp <= 0 then
        self.hp         = 0
        self.dead       = true
        self.deathTimer = 0
        self:spawnDeathParticles()
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

    for _, p in ipairs(self.particles) do p:draw() end
    for _, fb in ipairs(self.fireballs) do fb:draw() end

    if self:canRemove() then return end

    if self.state == ST.CHARGE and not self.charging then
        local cx2 = self.x + ts
        local cy2 = self.y + ts
        local pulse = math.abs(math.sin(love.timer.getTime() * 20))
        love.graphics.setColor(1, 0.3, 0, 0.5 * pulse)
        love.graphics.circle("line", cx2, cy2, ts * 1.2)
    end

    if self.enraged and not self.dead then
        local cx2 = self.x + ts
        local cy2 = self.y + ts
        local pulse = (math.sin(love.timer.getTime() * 8) + 1) * 0.5
        love.graphics.setColor(0.8, 0.1, 1, 0.15 + pulse * 0.1)
        love.graphics.circle("fill", cx2, cy2, ts * 1.4)
    end

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

    local shakeX, shakeY = 0, 0
    if self.screenShake > 0 then
        local mag = self.screenShake * 6
        shakeX = math.random(-mag, mag)
        shakeY = math.random(-mag, mag)
    end

    local f     = self.hitFlash
    local tf    = self.transFlash
    local alpha = self.dead and math.max(0, 1 - self.deathTimer) or 1

    if tf > 0 then
        love.graphics.setColor(1, 0.6 + tf * 0.4, tf, alpha)
    elseif self.enraged then
        love.graphics.setColor(1, 0.4 - f * 0.3, 1 - f * 0.5, alpha)
    else
        love.graphics.setColor(1, 1 - f * 0.7, 1 - f * 0.7, alpha)
    end

    love.graphics.draw(img, self.x + ox + shakeX, self.y + oy + shakeY, 0, SCALE * 2, SCALE * 2)
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
    if self.enraged then label = label .. "  !! ENRAGED" end
    love.graphics.print(label, bx, by - 14)

    love.graphics.setColor(0.25, 0.1, 0.1)
    love.graphics.rectangle("fill", bx, by, bw, bh, 3, 3)

    local pct = math.max(0, self.hp / self.maxHp)
    local barColor
    if self.enraged then
        barColor = { 0.9, 0.1, 1.0 }
    elseif self.phase == 2 then
        barColor = { 0.7, 0.2, 0.9 }
    else
        barColor = { 0.75, 0.15, 0.15 }
    end
    love.graphics.setColor(barColor)
    love.graphics.rectangle("fill", bx, by, math.floor(bw * pct), bh, 3, 3)

    local threshX = bx + math.floor(bw * (PHASE2_BONUS / (PHASE1_HP + PHASE2_BONUS)))
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.rectangle("fill", threshX - 1, by, 2, bh)

    if self.phase == 2 and not self.enraged then
        local remaining = math.max(0, 30 - self.enrageTimer)
        love.graphics.setColor(0.9, 0.5, 0.1, 0.8)
        love.graphics.print(string.format("ENRAGE in %.0fs", remaining), bx + bw + 8, by)
    end

    love.graphics.setColor(1, 1, 1)
end