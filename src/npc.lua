NPC = {}
NPC.__index = NPC

local TALK_RANGE = 56

local DIALOGUE_LINES = {
    oldman = {
        "Ah, a traveller...",
        "They say the forest east of here",
        "has been restless of late.",
        "Best keep your wits about you.",
    },
    merchant = {
        "Welcome, welcome!",
        "I have wares if you have coin.",
        "Come back once you've explored a bit.",
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

    n.dialogueLines = DIALOGUE_LINES[kind] or { "..." }
    n.dialogueIndex = 1
    n.dialogueOpen  = false
    n.talkCooldown  = 0

    local ok, snd   = pcall(love.audio.newSource, "assets/Sound/speak.wav", "static")
    n.speakSound    = ok and snd or nil
    if n.speakSound then n.speakSound:setVolume(0.35) end

    return n
end

function NPC:update(dt, player)
    n = self
    n.frameTime = n.frameTime + dt
    if n.frameTime >= n.frameDur then
        n.frameTime = 0
        n.frame = (n.frame == 1) and 2 or 1
    end

    if n.talkCooldown > 0 then
        n.talkCooldown = n.talkCooldown - dt
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
    local boxH = 80
    local boxX = 40
    local boxY = sh - boxH - 24

    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", boxX + 3, boxY + 3, boxW, boxH, 6, 6)

    love.graphics.setColor(0.08, 0.07, 0.12, 0.96)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 6, 6)

    love.graphics.setColor(0.55, 0.48, 0.35)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 6, 6)

    love.graphics.setColor(0.9, 0.78, 0.45)
    local label = self.kind:sub(1, 1):upper() .. self.kind:sub(2)
    love.graphics.print(label, boxX + 14, boxY + 10)

    love.graphics.setColor(0.92, 0.90, 0.86)
    local line = self.dialogueLines[self.dialogueIndex] or ""
    love.graphics.print(line, boxX + 14, boxY + 32)

    local hint = "[ E ] " .. (self.dialogueIndex < #self.dialogueLines and "next" or "close")
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print(hint, boxX + boxW - 80, boxY + boxH - 20)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setLineWidth(1)
end
