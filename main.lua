function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    TILE_SIZE = 16
    SCALE     = 3

    require("src/camera")
    require("src/world")
    require("src/player")
    require("src/npc")
    require("src/enemy")
    require("src/boss")

    math.randomseed(os.time())
    world              = World:new()
    camera             = Camera:new()
    player             = Player:new(world)
    player.x, player.y = world:findSpawn()

    world:revealFog(player)

    enemies       = spawnEnemies(world)
    boss          = Boss:new(10, 10)
    npcs          = {}

    killCount     = 0

    local ok, bgm = pcall(love.audio.newSource, "assets/Sound/HollowVale.wav", "stream")
    if ok then
        bgm:setLooping(true); bgm:setVolume(0.4); bgm:play()
        overworldMusic = bgm
    end

    gameState    = "playing"
    victoryTimer = 0
end

function spawnEnemies(world)
    local list  = {}
    local T     = World.T
    local kinds = { "orc", "greenslime", "redslime", "bat" }
    local count = 0
    local maxE  = 18

    math.randomseed(world.seed + 777)

    for r = 4, 60 do
        for c = 4, 60 do
            if count >= maxE then break end
            if not (r < 14 and c < 14) then
                if world:tileAt(c, r) == T.GRASS and math.random() < 0.008 then
                    table.insert(list, Enemy:new(kinds[math.random(#kinds)], c, r))
                    count = count + 1
                end
            end
        end
        if count >= maxE then break end
    end
    return list
end

function stopOverworldMusic()
    if overworldMusic then
        overworldMusic:stop(); overworldMusic = nil
    end
end

function love.update(dt)
    if gameState ~= "playing" then
        if gameState == "victory" then
            victoryTimer = victoryTimer + dt
        end
        return
    end

    world:update(dt)
    player:update(dt, world)
    camera:follow(player, world)

    world:revealFog(player)

    for _, npc in ipairs(npcs) do npc:update(dt, player) end

    local atkBox    = player:getAttackBox()
    local atkDamage = player:getAttackDamage()

    for i = #enemies, 1, -1 do
        local e = enemies[i]
        e:update(dt, player, world)
        if atkBox and not e.dead then
            local ts = TILE_SIZE * SCALE
            if atkBox.x < e.x + ts and atkBox.x + atkBox.w > e.x and
                atkBox.y < e.y + ts and atkBox.y + atkBox.h > e.y then
                e:takeDamage(atkDamage)
                if e.dead then killCount = killCount + 1 end
            end
        end
        if e:canRemove() then table.remove(enemies, i) end
    end

    if not boss:canRemove() then
        if boss.state ~= "idle" and overworldMusic then
            stopOverworldMusic()
        end

        boss:update(dt, player, world)

        if atkBox and not boss.dead then
            local ts2 = TILE_SIZE * SCALE * 2
            if atkBox.x < boss.x + ts2 and atkBox.x + atkBox.w > boss.x and
                atkBox.y < boss.y + ts2 and atkBox.y + atkBox.h > boss.y then
                boss:takeDamage(atkDamage)
            end
        end

        local bAtk = boss:getAttackBox()
        if bAtk then
            local ts = TILE_SIZE * SCALE
            local px, py = player.x + ts * 0.1, player.y + ts * 0.1
            local pw, ph = ts * 0.8, ts * 0.8
            if bAtk.x < px + pw and bAtk.x + bAtk.w > px and
                bAtk.y < py + ph and bAtk.y + bAtk.h > py then
                player:takeDamage(1)
            end
        end

        if boss.screenShake > 0 then
            camera:shake(boss.screenShake)
        end
    else
        if boss.dead and gameState == "playing" then
            gameState    = "victory"
            victoryTimer = 0
            local ok, s  = pcall(love.audio.newSource, "assets/Sound/fanfare.wav", "static")
            if ok then
                s:setVolume(0.8); s:play()
            end
        end
    end

    if player.screenShake > 0 then
        camera:shake(player.screenShake)
    end

    if player.hp <= 0 and gameState == "playing" then
        gameState = "gameover"
        stopOverworldMusic()
        boss:stopFightMusic()
        local ok, s = pcall(love.audio.newSource, "assets/Sound/gameover.wav", "static")
        if ok then
            s:setVolume(0.8); s:play()
        end
    end
end

function love.keypressed(key)
    if gameState == "victory" or gameState == "gameover" then
        if key == "return" or key == "space" then love.load() end
        return
    end

    if key == "space" or key == "z" then player:attack() end

    if key == "lshift" or key == "rshift" or key == "x" then
        player:tryRoll()
    end

    if key == "q" then
        player:useSelectedItem()
    end

    for n = 1, 9 do
        if key == tostring(n) then
            player:selectSlot(n)
            break
        end
    end


    if key == "e" then
        local item = world:tryOpenChest(player)
        if item then
            player:addItem(item)
            lastPickup      = item
            lastPickupTimer = 2.5
        else
            for _, npc in ipairs(npcs) do
                if npc:tryTalk(player) then break end
            end
        end
    end

    if key == "r" then
        world              = World:new()
        player.x, player.y = world:findSpawn()
        world:revealFog(player)
        enemies   = spawnEnemies(world)
        boss      = Boss:new(10, 10)
        killCount = 0
    end
end

function love.wheelmoved(x, y)
    if gameState ~= "playing" then return end
    if not player.inventory or #player.inventory == 0 then return end
    local n = player.selectedSlot - y
    n = ((n - 1) % #player.inventory) + 1
    player.selectedSlot = n
end

function love.draw()
    camera:attach()
    world:draw(camera)
    for _, npc in ipairs(npcs) do npc:draw() end
    for _, e in ipairs(enemies) do e:draw() end
    boss:draw()
    player:draw()
    camera:detach()

    player:drawHUD()
    player:drawInventory(world)
    boss:drawHUD()
    for _, npc in ipairs(npcs) do npc:drawDialogue() end

    world:drawMinimap(player, boss)

    love.graphics.setColor(1, 1, 0.6, 0.7)
    love.graphics.print("Kills: " .. (killCount or 0), love.graphics.getWidth() - 80, 10)

    if lastPickup and lastPickupTimer and lastPickupTimer > 0 then
        lastPickupTimer = lastPickupTimer - love.timer.getDelta()
        local alpha     = math.min(1, lastPickupTimer * 1.5)
        local sw        = love.graphics.getWidth()
        local sh        = love.graphics.getHeight()

        local tierColor = { 0.9, 0.8, 0.3 }

        love.graphics.setColor(0, 0, 0, alpha * 0.6)
        love.graphics.rectangle("fill", sw / 2 - 90, sh / 2 - 60, 180, 30, 6, 6)
        love.graphics.setColor(tierColor[1], tierColor[2], tierColor[3], alpha)
        love.graphics.printf("Found: " .. (lastPickup or ""), sw / 2 - 90, sh / 2 - 56, 180, "center")
        love.graphics.setColor(1, 1, 1)
    end

    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.print(
        "WASD move  |  Space/Z attack  |  Shift/X roll  |  E open/talk  |  Q use item  |  1-9 select  |  R new world",
        10, love.graphics.getHeight() - 20)
    love.graphics.setColor(1, 1, 1)

    if gameState == "victory" then drawVictory() end
    if gameState == "gameover" then drawGameOver() end
end

function drawVictory()
    local sw, sh = love.graphics.getDimensions()
    local alpha  = math.min(1, victoryTimer / 1.2)

    love.graphics.setColor(0, 0, 0, alpha * 0.6)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    love.graphics.setColor(0.9, 0.8, 0.3, alpha)
    love.graphics.printf("Victory!", 0, sh / 2 - 50, sw, "center")

    if victoryTimer > 1.5 then
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.printf(
            string.format("The Skeleton Lord has been defeated.\nEnemies slain: %d\n\nPress Space to play again",
                killCount or 0),
            0, sh / 2 + 10, sw, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

function drawGameOver()
    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setColor(0.85, 0.2, 0.2)
    love.graphics.printf("You Died", 0, sh / 2 - 40, sw, "center")
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf(
        string.format("Enemies slain: %d\n\nPress Space to try again", killCount or 0),
        0, sh / 2 + 10, sw, "center")
    love.graphics.setColor(1, 1, 1)
end

if Camera then
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
end