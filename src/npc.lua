NPC = {}
NPC.__index = NPC

local TALK_RANGE = 64

local DIALOGUE_POOLS = {
    oldman = {
        {
            "Ah, a traveller from afar...",
            "This village has stood for generations.",
            "But lately, dark things stir in the east.",
            "The Skeleton Lord grows bolder each night.",
            "Find him before he finds you.",
        },
        {
            "You look weary, friend.",
            "The forests here aren't safe after dark.",
            "Bats, slimes, orcs... they've multiplied.",
            "I'd rest here if I were you.",
        },
        {
            "The old ruins to the east...",
            "Nobody who goes there returns unchanged.",
            "Some don't return at all.",
            "Best keep your sword sharp.",
        },
    },
    merchant = {
        {
            "Welcome, welcome!",
            "A fine adventurer such as yourself",
            "deserves only the best goods.",
            "Check the chests scattered about — ",
            "many hold rare treasures worth having!",
        },
        {
            "Between you and me...",
            "The shield I sold to the last traveller",
            "saved her life against the boss.",
            "Equip everything you find — it all helps!",
        },
        {
            "The boots make you faster.",
            "The shield reduces damage taken.",
            "Potions restore two hearts.",
            "The axe upgrades your attack power!",
            "Use [ Q ] to equip or consume items.",
        },
    },
}

function NPC:new(kind, col, row, facing)
    local n    = setmetatable({}, NPC)
    n.kind     = kind
    n.facing   = facing or "down"
    n.x        = (col - 1) * TILE_SIZE * SCALE
    n.y        = (row - 1) * TILE_SIZE * SCALE

    local base = "assets/NPC/"
    local dirs = { "down", "up", "left", "right" }
    n.sprites  = {}
    for _, d in ipairs(dirs) do
        local f1 = base .. kind .. "_" .. d .. "_1.png"
        local f2 = base .. kind .. "_" .. d .. "_2.png"
        local ok1, i1 = pcall(love.graphics.newImage, f1)
        local ok2, i2 = pcall(love.graphics.newImage, f2)
        n.sprites[d] = {
            ok1 and i1 or nil,
            ok2 and i2 or nil,
        }
    end

    n.frame         = 1
    n.frameTime     = 0
    n.frameDur      = 0.6

    local pool      = DIALOGUE_POOLS[kind] or { { "..." } }
    n.dialogueLines = pool[math.random(#pool)]
    n.dialogueIndex = 1
    n.dialogueOpen  = false
    n.talkCooldown  = 0
    n.villageIndex  = 0

    local ok, snd   = pcall(love.audio.newSource, "assets/Sound/speak.wav", "static")
    n.speakSound    = ok and snd or nil
    if n.speakSound then n.speakSound:setVolume(0.35) end

    return n
end

function NPC:update(dt, player)
    local n = self
    n.frameTime = n.frameTime + dt
    if n.frameTime >= n.frameDur then
        n.frameTime = 0
        n.frame = (n.frame == 1) and 2 or 1
    end

    if n.talkCooldown > 0 then
        n.talkCooldown = n.talkCooldown - dt
    end

    if not n.dialogueOpen then
        local ts = TILE_SIZE * SCALE
        local dx = (player.x + ts / 2) - (n.x + ts / 2)
        local dy = (player.y + ts / 2) - (n.y + ts / 2)
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < TALK_RANGE * 1.5 then
            if math.abs(dx) > math.abs(dy) then
                n.facing = dx > 0 and "right" or "left"
            else
                n.facing = dy > 0 and "down" or "up"
            end
        end
    end
end

function NPC:tryTalk(player)
    local ts = TILE_SIZE * SCALE
    local dx = (player.x + ts / 2) - (self.x + ts / 2)
    local dy = (player.y + ts / 2) - (self.y + ts / 2)
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > TALK_RANGE then return false end
    if self.talkCooldown > 0 then return true end

    if self.dialogueOpen then
        self.dialogueIndex = self.dialogueIndex + 1
        if self.dialogueIndex > #self.dialogueLines then
            self.dialogueOpen  = false
            self.dialogueIndex = 1
            self.talkCooldown  = 0.4
            local pool         = DIALOGUE_POOLS[self.kind] or { { "..." } }
            self.dialogueLines = pool[math.random(#pool)]
        end
    else
        self.dialogueOpen  = true
        self.dialogueIndex = 1
    end

    if self.speakSound and self.dialogueOpen then
        self.speakSound:stop()
        self.speakSound:play()
    end

    return true
end

function NPC:draw()
    local imgs = self.sprites[self.facing]
    local img  = imgs and imgs[self.frame]
    if img then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(img, self.x, self.y, 0, SCALE, SCALE)
    end

end

function NPC:drawDialogue()
    if not self.dialogueOpen then return end

    local sw   = love.graphics.getWidth()
    local sh   = love.graphics.getHeight()

    local boxW = sw - 80
    local boxH = 90
    local boxX = 40
    local boxY = sh - boxH - 24

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", boxX + 4, boxY + 4, boxW, boxH, 6, 6)

    love.graphics.setColor(0.06, 0.05, 0.10, 0.97)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 6, 6)

    love.graphics.setColor(0.55, 0.48, 0.35)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 6, 6)
    love.graphics.setLineWidth(1)

    local portX = boxX + 12
    local portY = boxY + 12
    local portS = 66
    if self.kind == "merchant" then
        love.graphics.setColor(0.3, 0.6, 0.9, 0.8)
    else
        love.graphics.setColor(0.5, 0.4, 0.3, 0.8)
    end
    love.graphics.rectangle("fill", portX, portY, portS, portS, 4, 4)
    love.graphics.setColor(0.7, 0.6, 0.4)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", portX, portY, portS, portS, 4, 4)
    love.graphics.setLineWidth(1)

    local imgs = self.sprites["down"]
    local pimg = imgs and imgs[1]
    if pimg then
        love.graphics.setColor(1, 1, 1)
        local iw = pimg:getWidth()
        local ih = pimg:getHeight()
        local ps = math.min(portS / iw, portS / ih) * 0.85
        love.graphics.draw(pimg,
            portX + portS / 2 - iw * ps / 2,
            portY + portS / 2 - ih * ps / 2,
            0, ps, ps)
    end

    local textX = portX + portS + 12
    love.graphics.setColor(0.9, 0.78, 0.45)
    local label = self.kind:sub(1, 1):upper() .. self.kind:sub(2)
    love.graphics.print(label, textX, boxY + 12)

    love.graphics.setColor(0.92, 0.90, 0.86)
    local line = self.dialogueLines[self.dialogueIndex] or ""
    love.graphics.printf(line, textX, boxY + 32, boxW - textX + boxX - 12, "left")

    local dotY = boxY + boxH - 18
    for i = 1, #self.dialogueLines do
        if i == self.dialogueIndex then
            love.graphics.setColor(0.9, 0.78, 0.45, 1)
        else
            love.graphics.setColor(0.4, 0.38, 0.3, 0.7)
        end
        love.graphics.circle("fill", textX + (i - 1) * 12, dotY, 3)
    end

    local hint = "[ E ] " .. (self.dialogueIndex < #self.dialogueLines and "next" or "close")
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print(hint, boxX + boxW - 90, boxY + boxH - 20)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(1)
end

function NPC:drawProximityHint(player)
    local ts = TILE_SIZE * SCALE
    local dx = (player.x + ts / 2) - (self.x + ts / 2)
    local dy = (player.y + ts / 2) - (self.y + ts / 2)
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 48 and not self.dialogueOpen then
        love.graphics.setColor(1, 1, 0.6, 0.9)
        love.graphics.print("[E]", self.x + ts / 2 - 8, self.y - 18)
        love.graphics.setColor(1, 1, 1)
    end
end