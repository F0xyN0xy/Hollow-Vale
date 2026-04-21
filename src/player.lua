Player = {}
Player.__index = Player

function Player:new(world)
    local p            = setmetatable({}, Player)
    local ts           = TILE_SIZE * SCALE

    p.x                = 9 * ts
    p.y                = 7 * ts

    p.direction        = "down"
    p.moving           = false

    p.maxHp            = 6
    p.hp               = 6
    p.invincible       = 0
    p.invincibleMax    = 1.0

    p.maxStamina       = 3
    p.stamina          = 3
    p.staminaRegen     = 0.0
    p.staminaRegenRate = 1.5

    p.rolling          = false
    p.rollTimer        = 0
    p.rollDur          = 0.32
    p.rollCooldown     = 0
    p.rollDx           = 0
    p.rollDy           = 0
    p.rollSpeed        = 320 * SCALE

    p.swordLevel       = 1
    p.hasShield        = false
    p.hasLantern       = false
    p.hasBoots         = false
    p.coinCount        = 0

    p.frame            = 1
    p.frameTime        = 0
    p.frameDur         = 0.18

    p.attacking        = false
    p.attackTimer      = 0
    p.attackDur        = 0.25
    p.attackCooldown   = 0

    p.screenShake      = 0

    p.inventory        = {}
    p.itemCounts       = {}
    p.selectedSlot     = 1
    p.useFlash         = 0
    p.useFlashColor    = { 1, 1, 1 }

    local wb           = "assets/Player/Walking sprites/"
    p.walkSprites      = {
        down  = { love.graphics.newImage(wb .. "boy_down_1.png"), love.graphics.newImage(wb .. "boy_down_2.png") },
        up    = { love.graphics.newImage(wb .. "boy_up_1.png"), love.graphics.newImage(wb .. "boy_up_2.png") },
        left  = { love.graphics.newImage(wb .. "boy_left_1.png"), love.graphics.newImage(wb .. "boy_left_2.png") },
        right = { love.graphics.newImage(wb .. "boy_right_1.png"), love.graphics.newImage(wb .. "boy_right_2.png") },
    }

    local ab           = "assets/Attacking sprites/"
    p.attackSprites    = {
        down  = { love.graphics.newImage(ab .. "boy_attack_down_1.png"), love.graphics.newImage(ab .. "boy_attack_down_2.png") },
        up    = { love.graphics.newImage(ab .. "boy_attack_up_1.png"), love.graphics.newImage(ab .. "boy_attack_up_2.png") },
        left  = { love.graphics.newImage(ab .. "boy_attack_left_1.png"), love.graphics.newImage(ab .. "boy_attack_left_2.png") },
        right = { love.graphics.newImage(ab .. "boy_attack_right_1.png"), love.graphics.newImage(ab .. "boy_attack_right_2.png") },
    }

    local ok1, hf      = pcall(love.graphics.newImage, "assets/Object/heart_full.png")
    local ok2, hh      = pcall(love.graphics.newImage, "assets/Object/heart_half.png")
    local ok3, hb      = pcall(love.graphics.newImage, "assets/Object/heart_blank.png")
    p.heartFull        = ok1 and hf or nil
    p.heartHalf        = ok2 and hh or nil
    p.heartBlank       = ok3 and hb or nil

    local ok, ss       = pcall(love.audio.newSource, "assets/Sound/cursor.wav", "static")
    p.stepSound        = ok and ss or nil
    if p.stepSound then p.stepSound:setVolume(0.25) end
    p.stepTimer   = 0
    p.stepDur     = 0.36

    local okd, sd = pcall(love.audio.newSource, "assets/Sound/receivedamage.wav", "static")
    p.damageSound = okd and sd or nil
    if p.damageSound then p.damageSound:setVolume(0.6) end

    local okr, sr = pcall(love.audio.newSource, "assets/Sound/cursor.wav", "static")
    p.rollSound   = okr and sr or nil
    if p.rollSound then p.rollSound:setVolume(0.3) end

    local okp, sp = pcall(love.audio.newSource, "assets/Sound/coin.wav", "static")
    p.useSound    = okp and sp or nil
    if p.useSound then p.useSound:setVolume(0.5) end

    return p
end


local ITEM_META = {
    potion_red   = { label = "Red Potion", consumable = true, desc = "Restores 2 HP" },
    boots        = { label = "Swift Boots", consumable = false, desc = "Toggle speed boost" },
    lantern      = { label = "Lantern", consumable = false, desc = "Toggle wider fog reveal" },
    shield_blue  = { label = "Blue Shield", consumable = false, desc = "Toggle damage reduction" },
    axe          = { label = "Battle Axe", consumable = true, desc = "Upgrades sword level" },
    sword_normal = { label = "Iron Sword", consumable = true, desc = "Upgrades to sword Lv.2" },
    key          = { label = "Old Key", consumable = false, desc = "Opens locked doors (future)" },
    coin_bronze  = { label = "Bronze Coin", consumable = false, desc = "Currency (collected: see HUD)" },
}

local ITEM_USE = {
    potion_red = function(p)
        if p.hp >= p.maxHp then return false, "Already full HP!" end
        p:heal(2)
        p.useFlash      = 0.4
        p.useFlashColor = { 0.4, 1, 0.4 }
        return true, "Restored 2 HP"
    end,

    boots = function(p)
        p.hasBoots      = not p.hasBoots
        p.useFlash      = 0.3
        p.useFlashColor = { 0.8, 0.6, 0.2 }
        return true, p.hasBoots and "Boots equipped!" or "Boots unequipped"
    end,

    lantern = function(p)
        p.hasLantern    = not p.hasLantern
        p.useFlash      = 0.3
        p.useFlashColor = { 1, 0.9, 0.3 }
        return true, p.hasLantern and "Lantern lit!" or "Lantern off"
    end,

    shield_blue = function(p)
        p.hasShield     = not p.hasShield
        p.useFlash      = 0.3
        p.useFlashColor = { 0.4, 0.6, 1 }
        return true, p.hasShield and "Shield raised!" or "Shield lowered"
    end,

    axe = function(p)
        if p.swordLevel >= 3 then return false, "Already max level!" end
        p.swordLevel    = p.swordLevel + 1
        p.useFlash      = 0.5
        p.useFlashColor = { 1, 0.5, 0.1 }
        return true, "Sword upgraded to Lv." .. p.swordLevel
    end,

    sword_normal = function(p)
        if p.swordLevel >= 2 then return false, "Already upgraded!" end
        p.swordLevel    = 2
        p.useFlash      = 0.5
        p.useFlashColor = { 1, 0.9, 0.2 }
        return true, "Sword upgraded to Lv.2!"
    end,

    key = function(p)
        return false, "Saved for locked doors..."
    end,

    coin_bronze = function(p)
        p.coinCount = p.coinCount + (p.itemCounts["coin_bronze"] or 0)
        p.itemCounts["coin_bronze"] = 0
        for i = #p.inventory, 1, -1 do
            if p.inventory[i] == "coin_bronze" then
                table.remove(p.inventory, i)
                break
            end
        end
        p.useFlash      = 0.25
        p.useFlashColor = { 1, 0.9, 0.1 }
        return true, "Coins stashed!"
    end,
}


function Player:takeDamage(dmg)
    if self.invincible > 0 or self.rolling then return end
    if self.hasShield then dmg = math.max(1, dmg - 1) end
    self.hp          = math.max(0, self.hp - dmg)
    self.invincible  = self.invincibleMax
    self.screenShake = 0.3
    if self.damageSound then
        self.damageSound:stop(); self.damageSound:play()
    end
end

function Player:heal(amount)
    self.hp = math.min(self.maxHp, self.hp + amount)
end


function Player:getAttackBox()
    if not self.attacking then return nil end
    local ts    = TILE_SIZE * SCALE
    local reach = ts * (self.swordLevel >= 3 and 1.5 or self.swordLevel >= 2 and 1.2 or 0.9)
    local thick = ts * 0.7
    local cx    = self.x + ts / 2
    local cy    = self.y + ts / 2
    local d     = self.direction
    if d == "right" then return { x = cx, y = cy - thick / 2, w = reach, h = thick } end
    if d == "left" then return { x = cx - reach, y = cy - thick / 2, w = reach, h = thick } end
    if d == "down" then return { x = cx - thick / 2, y = cy, w = thick, h = reach } end
    if d == "up" then return { x = cx - thick / 2, y = cy - reach, w = thick, h = reach } end
end

function Player:getAttackDamage()
    if self.swordLevel >= 3 then return 3 end
    if self.swordLevel >= 2 then return 2 end
    return 1
end


function Player:tryRoll()
    if self.rolling or self.rollCooldown > 0 or self.stamina < 1 then return end
    if self.attacking then return end

    local dx, dy = 0, 0
    if love.keyboard.isDown("up", "w") then dy = -1 end
    if love.keyboard.isDown("down", "s") then dy = 1 end
    if love.keyboard.isDown("left", "a") then dx = -1 end
    if love.keyboard.isDown("right", "d") then dx = 1 end

    if dx == 0 and dy == 0 then
        local dir = self.direction
        if dir == "up" then
            dy = -1
        elseif dir == "down" then
            dy = 1
        elseif dir == "left" then
            dx = -1
        elseif dir == "right" then
            dx = 1
        end
    end

    if dx ~= 0 and dy ~= 0 then
        dx = dx * 0.7071; dy = dy * 0.7071
    end

    self.rolling      = true
    self.rollTimer    = self.rollDur
    self.rollDx       = dx
    self.rollDy       = dy
    self.rollCooldown = 0.5
    self.stamina      = self.stamina - 1
    self.staminaRegen = 0
    self.invincible   = self.rollDur

    if self.rollSound then
        self.rollSound:stop(); self.rollSound:play()
    end
end


function Player:addItem(itemName)
    if not self.inventory then self.inventory = {} end
    if not self.itemCounts then self.itemCounts = {} end

    if itemName == "coin_bronze" then
        self.coinCount = (self.coinCount or 0) + 1
        return
    end

    self.itemCounts[itemName] = (self.itemCounts[itemName] or 0) + 1

    local found = false
    for _, name in ipairs(self.inventory) do
        if name == itemName then
            found = true; break
        end
    end
    if not found then
        table.insert(self.inventory, itemName)
    end

    if itemName == "boots" then
        self.hasBoots = true
    end
end

function Player:useSelectedItem()
    if not self.inventory or #self.inventory == 0 then return end
    local slot = math.min(self.selectedSlot, #self.inventory)
    local name = self.inventory[slot]
    if not name then return end

    local count = self.itemCounts[name] or 0
    if count <= 0 then return end

    local useFn = ITEM_USE[name]
    if not useFn then return end

    local used, msg = useFn(self)

    if used then
        local meta = ITEM_META[name]
        if meta and meta.consumable then
            self.itemCounts[name] = self.itemCounts[name] - 1
            if self.itemCounts[name] <= 0 then
                self.itemCounts[name] = 0
                table.remove(self.inventory, slot)
                self.selectedSlot = math.max(1, math.min(self.selectedSlot, math.max(1, #self.inventory)))
            end
        end
        if self.useSound then
            self.useSound:stop(); self.useSound:play()
        end
    end
end

function Player:selectSlot(n)
    if not self.inventory then return end
    self.selectedSlot = math.max(1, math.min(n, math.max(1, #self.inventory)))
end


function Player:update(dt, world)
    local ts  = TILE_SIZE * SCALE
    local spd = 160 * SCALE
    if self.hasBoots then spd = spd * 1.35 end

    if self.hasLantern then
    end

    if self.invincible > 0 then
        self.invincible = math.max(0, self.invincible - dt)
    end
    if self.rollCooldown > 0 then
        self.rollCooldown = math.max(0, self.rollCooldown - dt)
    end
    if self.attackCooldown > 0 then
        self.attackCooldown = math.max(0, self.attackCooldown - dt)
    end
    if self.screenShake > 0 then
        self.screenShake = math.max(0, self.screenShake - dt * 3)
    end
    if self.useFlash > 0 then
        self.useFlash = math.max(0, self.useFlash - dt * 3)
    end

    if self.stamina < self.maxStamina then
        self.staminaRegen = self.staminaRegen + dt
        if self.staminaRegen >= self.staminaRegenRate then
            self.staminaRegen = 0
            self.stamina = math.min(self.maxStamina, self.stamina + 1)
        end
    end

    if self.attacking then
        self.attackTimer = self.attackTimer + dt
        if self.attackTimer >= self.attackDur then
            self.attacking   = false
            self.attackTimer = 0
        end
    end

    if self.rolling then
        self.rollTimer = self.rollTimer - dt
        if self.rollTimer <= 0 then
            self.rolling = false
        else
            local margin = 4
            local pw, ph = ts - margin * 2, ts - margin * 2
            local rx = self.x + self.rollDx * self.rollSpeed * dt
            local ry = self.y + self.rollDy * self.rollSpeed * dt
            if not world:isSolid(rx + margin, self.y + margin, pw, ph) then self.x = rx end
            if not world:isSolid(self.x + margin, ry + margin, pw, ph) then self.y = ry end
        end
        self.frameTime = self.frameTime + dt * 2
        if self.frameTime >= self.frameDur then
            self.frameTime = 0
            self.frame = (self.frame == 1) and 2 or 1
        end
        return
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
    self.moving  = (dx ~= 0 or dy ~= 0)

    local margin = 4
    local pw, ph = ts - margin * 2, ts - margin * 2
    local newX   = self.x + dx * spd * dt
    local newY   = self.y + dy * spd * dt
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
    if self.attacking or self.attackCooldown > 0 or self.rolling then return end
    self.attacking      = true
    self.attackTimer    = 0
    self.attackCooldown = 0.4
end


function Player:draw()
    if self.invincible > 0 and not self.rolling then
        if math.floor(self.invincible * 10) % 2 == 0 then return end
    end

    local sprites = self.attacking and self.attackSprites or self.walkSprites
    local img     = sprites[self.direction][self.frame]

    local ox, oy  = 0, 0
    if self.attacking then
        if self.direction == "up" then oy = -TILE_SIZE * SCALE end
        if self.direction == "left" then ox = -TILE_SIZE * SCALE end
    end

    local sx, sy = SCALE, SCALE
    if self.rolling then
        local t = 1 - (self.rollTimer / self.rollDur)
        sx      = SCALE * (1 + math.sin(t * math.pi) * 0.3)
        sy      = SCALE * (1 - math.sin(t * math.pi) * 0.2)
        love.graphics.setColor(0.7, 0.85, 1, 0.6)
    elseif self.useFlash > 0 then
        local f  = self.useFlash
        local fc = self.useFlashColor or { 1, 1, 1 }
        love.graphics.setColor(
            0.6 + fc[1] * 0.4 * f,
            0.6 + fc[2] * 0.4 * f,
            0.6 + fc[3] * 0.4 * f, 1)
    else
        love.graphics.setColor(1, 1, 1)
    end

    if self.hasShield and not self.rolling then
        love.graphics.setColor(0.4, 0.6, 1, 0.25)
        love.graphics.draw(img, self.x + ox - 1, self.y + oy, 0, sx, sy)
        love.graphics.draw(img, self.x + ox + 1, self.y + oy, 0, sx, sy)
        love.graphics.setColor(1, 1, 1)
    end

    love.graphics.draw(img, self.x + ox, self.y + oy, 0, sx, sy)
    love.graphics.setColor(1, 1, 1)
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

    local pipY   = startY + 16 * hpScale + 4
    local pipW   = 12
    local pipH   = 6
    local pipGap = 3
    for i = 1, self.maxStamina do
        local filled = i <= self.stamina
        love.graphics.setColor(filled and 0.2 or 0.15, filled and 0.7 or 0.25, filled and 1.0 or 0.35, 0.9)
        love.graphics.rectangle("fill", startX + (i - 1) * (pipW + pipGap), pipY, pipW, pipH, 2, 2)
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("line", startX + (i - 1) * (pipW + pipGap), pipY, pipW, pipH, 2, 2)
    end

    local badgeX = startX
    local badgeY = pipY + pipH + 6
    local function badge(r, g, b, icon, label)
        love.graphics.setColor(r, g, b, 0.9)
        love.graphics.print(icon .. " " .. label, badgeX, badgeY, 0, 0.78, 0.78)
        badgeX = badgeX + love.graphics.getFont():getWidth(icon .. " " .. label) * 0.78 + 8
    end
    if self.hasBoots then badge(0.9, 0.7, 0.2, ">>", "Fast") end
    if self.hasShield then badge(0.4, 0.6, 1, "[]", "Shield") end
    if self.hasLantern then badge(1, 0.9, 0.3, "o", "Lantern") end
    if self.swordLevel >= 3 then
        badge(1, 0.4, 0.1, "**", "Lv.3")
    elseif self.swordLevel >= 2 then
        badge(1, 0.85, 0.2, "*", "Lv.2")
    end
    if (self.coinCount or 0) > 0 then
        badge(1, 0.85, 0.1, "$", tostring(self.coinCount))
    end

    love.graphics.setColor(1, 1, 1)
end


function Player:drawInventory(world)
    if not self.inventory or #self.inventory == 0 then return end

    local sh     = love.graphics.getHeight()
    local SLOT   = 40
    local PAD    = 5
    local GAP    = 3
    local n      = #self.inventory
    local totalW = n * (SLOT + GAP) - GAP + PAD * 2
    local startX = 10
    local startY = sh - SLOT - 28

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", startX - PAD, startY - PAD - 2,
        totalW, SLOT + PAD * 2 + 22, 5, 5)
    love.graphics.setColor(0.4, 0.35, 0.25, 0.7)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", startX - PAD, startY - PAD - 2,
        totalW, SLOT + PAD * 2 + 22, 5, 5)
    love.graphics.setLineWidth(1)

    for i, item in ipairs(self.inventory) do
        local x     = startX + (i - 1) * (SLOT + GAP)
        local sel   = (i == self.selectedSlot)
        local count = self.itemCounts[item] or 0
        local meta  = ITEM_META[item]

        if sel then
            love.graphics.setColor(0.9, 0.75, 0.2, 0.75)
        else
            love.graphics.setColor(0.18, 0.15, 0.12, 0.85)
        end
        love.graphics.rectangle("fill", x, startY, SLOT, SLOT, 4, 4)

        love.graphics.setColor(sel and 1 or 0.4, sel and 0.85 or 0.38, sel and 0.1 or 0.28, 1)
        love.graphics.setLineWidth(sel and 2 or 1)
        love.graphics.rectangle("line", x, startY, SLOT, SLOT, 4, 4)
        love.graphics.setLineWidth(1)

        local img = world and world.itemSprites and world.itemSprites[item]
        if img then
            love.graphics.setColor(1, 1, 1)
            local iw  = img:getWidth()
            local ih  = img:getHeight()
            local sc  = (SLOT * 0.8) / math.max(iw, ih)
            local ox2 = (SLOT - iw * sc) / 2
            local oy2 = (SLOT - ih * sc) / 2
            love.graphics.draw(img, x + ox2, startY + oy2, 0, sc, sc)
        else
            love.graphics.setColor(0.6, 0.5, 0.2)
            love.graphics.rectangle("fill", x + 6, startY + 6, SLOT - 12, SLOT - 12, 3, 3)
        end

        if meta and meta.consumable and count > 1 then
            love.graphics.setColor(0, 0, 0, 0.75)
            love.graphics.rectangle("fill", x + SLOT - 15, startY + SLOT - 14, 14, 13, 2, 2)
            love.graphics.setColor(1, 1, 0.7)
            love.graphics.print(tostring(count), x + SLOT - 14, startY + SLOT - 14, 0, 0.8, 0.8)
        end

        love.graphics.setColor(0.55, 0.55, 0.55, 0.8)
        love.graphics.print(tostring(i), x + 3, startY + 2, 0, 0.65, 0.65)

        if not (meta and meta.consumable) then
            local active = false
            if item == "boots" and self.hasBoots then active = true end
            if item == "shield_blue" and self.hasShield then active = true end
            if item == "lantern" and self.hasLantern then active = true end
            if active then
                love.graphics.setColor(0.3, 1, 0.4, 0.9)
                love.graphics.circle("fill", x + SLOT - 5, startY + 5, 4)
            end
        end
    end

    if self.inventory[self.selectedSlot] then
        local item = self.inventory[self.selectedSlot]
        local meta = ITEM_META[item]
        if meta then
            local tipX = startX
            local tipY = startY + SLOT + 4
            love.graphics.setColor(0.8, 0.8, 0.6, 0.85)
            love.graphics.print(meta.label .. "  —  " .. meta.desc, tipX, tipY, 0, 0.72, 0.72)
        end
    end

    love.graphics.setColor(1, 1, 1)
end