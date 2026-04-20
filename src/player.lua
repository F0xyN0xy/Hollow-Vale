Player = {}
Player.__index = Player

function Player:new(world)
    local p          = setmetatable({}, Player)
    local ts         = TILE_SIZE * SCALE

    p.x              = 9 * ts
    p.y              = 7 * ts

    p.direction      = "down"
    p.moving         = false

    p.maxHp          = 6
    p.hp             = 6
    p.invincible     = 0
    p.invincibleMax  = 1.0

    p.frame          = 1
    p.frameTime      = 0
    p.frameDur       = 0.18

    p.attacking      = false
    p.attackTimer    = 0
    p.attackDur      = 0.25
    p.attackCooldown = 0

    local wb         = "assets/Player/Walking sprites/"
    p.walkSprites    = {
        down  = { love.graphics.newImage(wb .. "boy_down_1.png"), love.graphics.newImage(wb .. "boy_down_2.png") },
        up    = { love.graphics.newImage(wb .. "boy_up_1.png"), love.graphics.newImage(wb .. "boy_up_2.png") },
        left  = { love.graphics.newImage(wb .. "boy_left_1.png"), love.graphics.newImage(wb .. "boy_left_2.png") },
        right = { love.graphics.newImage(wb .. "boy_right_1.png"), love.graphics.newImage(wb .. "boy_right_2.png") },
    }

    local ab         = "assets/Attacking sprites/"
    p.attackSprites  = {
        down  = { love.graphics.newImage(ab .. "boy_attack_down_1.png"), love.graphics.newImage(ab .. "boy_attack_down_2.png") },
        up    = { love.graphics.newImage(ab .. "boy_attack_up_1.png"), love.graphics.newImage(ab .. "boy_attack_up_2.png") },
        left  = { love.graphics.newImage(ab .. "boy_attack_left_1.png"), love.graphics.newImage(ab .. "boy_attack_left_2.png") },
        right = { love.graphics.newImage(ab .. "boy_attack_right_1.png"), love.graphics.newImage(ab .. "boy_attack_right_2.png") },
    }

    local ok1, hf    = pcall(love.graphics.newImage, "assets/Object/heart_full.png")
    local ok2, hh    = pcall(love.graphics.newImage, "assets/Object/heart_half.png")
    local ok3, hb    = pcall(love.graphics.newImage, "assets/Object/heart_blank.png")
    p.heartFull      = ok1 and hf or nil
    p.heartHalf      = ok2 and hh or nil
    p.heartBlank     = ok3 and hb or nil

    local ok, ss     = pcall(love.audio.newSource, "assets/Sound/cursor.wav", "static")
    p.stepSound      = ok and ss or nil
    if p.stepSound then p.stepSound:setVolume(0.25) end
    p.stepTimer   = 0
    p.stepDur     = 0.36

    local okd, sd = pcall(love.audio.newSource, "assets/Sound/receivedamage.wav", "static")
    p.damageSound = okd and sd or nil
    if p.damageSound then p.damageSound:setVolume(0.6) end

    return p
end

function Player:takeDamage(dmg)
    if self.invincible > 0 then return end
    self.hp = math.max(0, self.hp - dmg)
    self.invincible = self.invincibleMax
    if self.damageSound then
        self.damageSound:stop(); self.damageSound:play()
    end
end

function Player:getAttackBox()
    if not self.attacking then return nil end
    local ts    = TILE_SIZE * SCALE
    local reach = ts * 0.9
    local thick = ts * 0.7
    local cx    = self.x + ts / 2
    local cy    = self.y + ts / 2
    local d     = self.direction
    if d == "right" then return { x = cx, y = cy - thick / 2, w = reach, h = thick } end
    if d == "left" then return { x = cx - reach, y = cy - thick / 2, w = reach, h = thick } end
    if d == "down" then return { x = cx - thick / 2, y = cy, w = thick, h = reach } end
    if d == "up" then return { x = cx - thick / 2, y = cy - reach, w = thick, h = reach } end
end

function Player:update(dt, world)
    local ts  = TILE_SIZE * SCALE
    local spd = 160 * SCALE

    if self.invincible > 0 then
        self.invincible = math.max(0, self.invincible - dt)
    end

    if self.attacking then
        self.attackTimer = self.attackTimer + dt
        if self.attackTimer >= self.attackDur then
            self.attacking   = false
            self.attackTimer = 0
        end
    end
    if self.attackCooldown > 0 then
        self.attackCooldown = math.max(0, self.attackCooldown - dt)
    end

    local dx, dy = 0, 0
    if not self.attacking then
        if love.keyboard.isDown("up", "w") then
            dy = -1; self.direction = "up"
        end
        if love.keyboard.isDown("down", "s") then
            dy = 1; self.direction = "down"
        end
        if love.keyboard.isDown("left", "a") then
            dx = -1; self.direction = "left"
        end
        if love.keyboard.isDown("right", "d") then
            dx = 1; self.direction = "right"
        end
    end

    if dx ~= 0 and dy ~= 0 then
        dx = dx * 0.7071; dy = dy * 0.7071
    end
    self.moving = (dx ~= 0 or dy ~= 0)

    local margin = 4
    local pw, ph = ts - margin * 2, ts - margin * 2
    local newX = self.x + dx * spd * dt
    local newY = self.y + dy * spd * dt
    if not world:isSolid(newX + margin, self.y + margin, pw, ph) then self.x = newX end
    if not world:isSolid(self.x + margin, newY + margin, pw, ph) then self.y = newY end

    if self.moving and not self.attacking then
        self.frameTime = self.frameTime + dt
        if self.frameTime >= self.frameDur then
            self.frameTime = 0
            self.frame = (self.frame == 1) and 2 or 1
        end
        self.stepTimer = self.stepTimer + dt
        if self.stepTimer >= self.stepDur then
            self.stepTimer = 0
            if self.stepSound then
                self.stepSound:stop(); self.stepSound:play()
            end
        end
    else
        self.frame = 1; self.frameTime = 0; self.stepTimer = 0
    end
end

function Player:attack()
    if self.attacking or self.attackCooldown > 0 then return end
    self.attacking      = true
    self.attackTimer    = 0
    self.attackCooldown = 0.4
end

function Player:draw()
    if self.invincible > 0 and math.floor(self.invincible * 10) % 2 == 0 then return end

    local sprites = self.attacking and self.attackSprites or self.walkSprites
    local img = sprites[self.direction][self.frame]

    local ox, oy = 0, 0
    if self.attacking then
        if self.direction == "up" then oy = -TILE_SIZE * SCALE end
        if self.direction == "left" then ox = -TILE_SIZE * SCALE end
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(img, self.x + ox, self.y + oy, 0, SCALE, SCALE)
end

function Player:drawHUD()
    local hpScale = SCALE * 0.9
    local iconW   = 16 * hpScale + 2
    local startX  = 10
    local startY  = 10
    local hearts  = self.maxHp / 2

    for i = 1, hearts do
        local hpVal = self.hp - (i - 1) * 2
        local img
        if hpVal >= 2 then
            img = self.heartFull
        elseif hpVal == 1 then
            img = self.heartHalf
        else
            img = self.heartBlank
        end
        if img then
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(img, startX + (i - 1) * iconW, startY, 0, hpScale, hpScale)
        else
            if hpVal >= 2 then
                love.graphics.setColor(0.9, 0.2, 0.2)
            elseif hpVal == 1 then
                love.graphics.setColor(0.9, 0.5, 0.2)
            else
                love.graphics.setColor(0.3, 0.3, 0.3)
            end
            love.graphics.rectangle("fill", startX + (i - 1) * iconW, startY, 14 * hpScale, 14 * hpScale, 2, 2)
        end
    end
    love.graphics.setColor(1, 1, 1)
end

function Player:addItem(itemName)
    if not self.inventory then self.inventory = {} end
    table.insert(self.inventory, itemName)

    if itemName == "potion_red" then
        self.hp = math.min(self.maxHp, self.hp + 2)
    elseif itemName == "boots" then
        self.hasBoots = true
    end
end

function Player:drawInventory(world)
    if not self.inventory or #self.inventory == 0 then return end
    local sh     = love.graphics.getHeight()
    local ts     = 16 * 2
    local pad    = 4
    local startX = 10
    local startY = sh - ts - 14

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", startX - pad, startY - pad,
        #self.inventory * (ts + pad) + pad, ts + pad * 2, 4, 4)

    for i, item in ipairs(self.inventory) do
        local img = world and world.itemSprites and world.itemSprites[item]
        local x = startX + (i - 1) * (ts + pad)
        if img then
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(img, x, startY, 0, 2, 2)
        else
            love.graphics.setColor(0.8, 0.6, 0.2)
            love.graphics.rectangle("fill", x, startY, ts, ts, 3, 3)
        end
    end
    love.graphics.setColor(1, 1, 1)
end
