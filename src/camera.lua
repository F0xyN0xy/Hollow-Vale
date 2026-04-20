Camera = {}
Camera.__index = Camera

function Camera:new()
    local c = setmetatable({}, Camera)
    c.x = 0
    c.y = 0
    return c
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
end

function Camera:attach()
    love.graphics.push()
    love.graphics.translate(-math.floor(self.x), -math.floor(self.y))
end

function Camera:detach()
    love.graphics.pop()
end