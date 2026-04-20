Camera = {}
Camera.__index = Camera

function Camera:new()
    local c     = setmetatable({}, Camera)
    c.x         = 0
    c.y         = 0
    c.shakeAmt  = 0
    c.shakeOffX = 0
    c.shakeOffY = 0
    return c
end

function Camera:shake(amount)
    self.shakeAmt = math.max(self.shakeAmt, amount)
end

function Camera:follow(player, world)
    local sw, sh = love.graphics.getDimensions()

    local tx = player.x + (TILE_SIZE * SCALE) / 2 - sw / 2
    local ty = player.y + (TILE_SIZE * SCALE) / 2 - sh / 2

    self.x = self.x + (tx - self.x) * 0.12
    self.y = self.y + (ty - self.y) * 0.12

    local worldPixelW = world.cols * TILE_SIZE * SCALE
    local worldPixelH = world.rows * TILE_SIZE * SCALE
    self.x = math.max(0, math.min(self.x, worldPixelW - sw))
    self.y = math.max(0, math.min(self.y, worldPixelH - sh))

    if self.shakeAmt > 0 then
        local mag      = self.shakeAmt * 8
        self.shakeOffX = math.random(-math.floor(mag), math.floor(mag))
        self.shakeOffY = math.random(-math.floor(mag), math.floor(mag))
        self.shakeAmt  = self.shakeAmt * 0.75
        if self.shakeAmt < 0.01 then
            self.shakeAmt  = 0
            self.shakeOffX = 0
            self.shakeOffY = 0
        end
    end
end

function Camera:attach()
    love.graphics.push()
    love.graphics.translate(
        -math.floor(self.x) + self.shakeOffX,
        -math.floor(self.y) + self.shakeOffY)
end

function Camera:detach()
    love.graphics.pop()
end