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
    initGame()
end

function initGame()
    world              = World:new()
    camera             = Camera:new()
    player             = Player:new(world)
    player.x, player.y = world:findSpawn()

    world:revealFog(player)

    enemies          = spawnEnemies(world)
    local bCol, bRow = world:findBossSpawn()
    boss             = Boss:new(bCol, bRow)
    npcs             = world:spawnVillageNPCs()

    killCount        = 0
    showMap          = false

    local ok, bgm    = pcall(love.audio.newSource, "assets/Sound/HollowVale.wav", "stream")
    if ok then
        bgm:setLooping(true); bgm:setVolume(0.4); bgm:play()
        overworldMusic = bgm
    else
        overworldMusic = nil
    end

    gameState       = "playing"
    victoryTimer    = 0
    lastPickup      = nil
    lastPickupTimer = 0
end

function spawnEnemies(world)
    local list  = {}
    local T     = World.T
    local kinds = { "orc", "greenslime", "redslime", "bat" }
    local count = 0
    local maxE  = 30

    math.randomseed(world.seed + 777)

    for r = 4, 100 do
        for c = 4, 100 do
            if count >= maxE then break end
            if not (r < 18 and c < 18) then
                if world:tileAt(c, r) == T.GRASS and math.random() < 0.006 then
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

    if showMap then return end

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
        if key == "return" or key == "space" then initGame() end
        return
    end

    if key == "m" then
        showMap = not showMap
        return
    end

    if showMap then return end

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
        stopOverworldMusic()
        if boss and boss.bossMusic then boss:stopFightMusic() end
        initGame()
    end
end

function love.wheelmoved(x, y)
    if gameState ~= "playing" or showMap then return end
    if not player.inventory or #player.inventory == 0 then return end
    local n = player.selectedSlot - y
    n = ((n - 1) % #player.inventory) + 1
    player.selectedSlot = n
end

function love.draw()
    if showMap then
        drawFullMap()
        return
    end

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

        love.graphics.setColor(0, 0, 0, alpha * 0.6)
        love.graphics.rectangle("fill", sw / 2 - 100, sh / 2 - 60, 200, 30, 6, 6)
        love.graphics.setColor(1, 0.9, 0.4, alpha)
        love.graphics.printf("Found: " .. (lastPickup or ""), sw / 2 - 100, sh / 2 - 56, 200, "center")
        love.graphics.setColor(1, 1, 1)
    end

    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.print(
        "WASD move | Space/Z attack | Shift/X roll | E interact | Q use item | 1-9 select | M map | R new world",
        10, love.graphics.getHeight() - 20)
    love.graphics.setColor(1, 1, 1)

    if gameState == "victory" then drawVictory() end
    if gameState == "gameover" then drawGameOver() end
end

function drawFullMap()
    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0.05, 0.04, 0.08)
    love.graphics.rectangle("fill", 0, 0, sw, sh)

    local mapW      = math.min(sw - 40, sh - 80)
    local mapH      = mapW
    local mapX      = (sw - mapW) / 2
    local mapY      = (sh - mapH) / 2 + 20
    local cols      = world.cols
    local rows      = world.rows
    local cellW     = mapW / cols
    local cellH     = mapH / rows

    local T         = World.T
    local IS_W      = {
        [T.WATER] = true,
        [T.WATER_N] = true,
        [T.WATER_S] = true,
        [T.WATER_E] = true,
        [T.WATER_W] = true,
        [T.WATER_NE] = true,
        [T.WATER_NW] = true,
        [T.WATER_SE] = true,
        [T.WATER_SW] = true
    }

    local FOG_SCALE = 2
    for r = 1, rows, 2 do
        for c = 1, cols, 2 do
            local fc = math.floor(c / FOG_SCALE)
            local fr = math.floor(r / FOG_SCALE)
            if world:isFogRevealed(fc, fr) then
                local id = world:tileAt(c, r)
                if IS_W[id] or id == T.WATER then
                    love.graphics.setColor(0.15, 0.35, 0.65)
                elseif id == T.TREE then
                    love.graphics.setColor(0.1, 0.38, 0.12)
                elseif id == T.EARTH then
                    love.graphics.setColor(0.48, 0.36, 0.20)
                else
                    love.graphics.setColor(0.22, 0.44, 0.18)
                end
                local px = mapX + (c - 1) * cellW
                local py = mapY + (r - 1) * cellH
                love.graphics.rectangle("fill", px, py, math.max(1, cellW * 2), math.max(1, cellH * 2))
            end
        end
    end

    for _, v in ipairs(world.villages or {}) do
        local fc = math.floor(v.col / FOG_SCALE)
        local fr = math.floor(v.row / FOG_SCALE)
        if world:isFogRevealed(fc, fr) then
            local px = mapX + (v.col - 1) * cellW
            local py = mapY + (v.row - 1) * cellH
            love.graphics.setColor(0.9, 0.75, 0.3, 0.9)
            love.graphics.rectangle("fill", px - 3, py - 3, 6, 6)
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.print("Village", px + 5, py - 4, 0, 0.65, 0.65)
        end
    end

    for _, ch in ipairs(world.chests) do
        if not ch.opened then
            local fc = math.floor(ch.col / FOG_SCALE)
            local fr = math.floor(ch.row / FOG_SCALE)
            if world:isFogRevealed(fc, fr) then
                local px = mapX + (ch.col - 1) * cellW
                local py = mapY + (ch.row - 1) * cellH
                if ch.tier == "rare" then
                    love.graphics.setColor(0.85, 0.3, 1)
                elseif ch.tier == "uncommon" then
                    love.graphics.setColor(0.3, 1, 0.4)
                else
                    love.graphics.setColor(0.9, 0.8, 0.2)
                end
                love.graphics.rectangle("fill", px - 1, py - 1, 3, 3)
            end
        end
    end

    if boss and not boss:canRemove() then
        local ts = TILE_SIZE * SCALE
        local bc = math.floor(boss.x / ts) + 1
        local br = math.floor(boss.y / ts) + 1
        local fc = math.floor(bc / FOG_SCALE)
        local fr = math.floor(br / FOG_SCALE)
        if world:isFogRevealed(fc, fr) then
            local px = mapX + (bc - 1) * cellW
            local py = mapY + (br - 1) * cellH
            local pulse = (math.sin(love.timer.getTime() * 4) + 1) * 0.5
            love.graphics.setColor(1, 0.1, 0.1, 0.7 + pulse * 0.3)
            love.graphics.rectangle("fill", px - 4, py - 4, 8, 8)
            love.graphics.setColor(1, 0.4, 0.4, 0.9)
            love.graphics.print("BOSS", px + 5, py - 4, 0, 0.65, 0.65)
        end
    end

    local ts  = TILE_SIZE * SCALE
    local pc  = math.floor(player.x / ts) + 1
    local pr  = math.floor(player.y / ts) + 1
    local ppx = mapX + (pc - 1) * cellW
    local ppy = mapY + (pr - 1) * cellH
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("fill", ppx - 3, ppy - 3, 6, 6)
    love.graphics.setColor(0.3, 0.7, 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", ppx - 3, ppy - 3, 6, 6)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(0.6, 0.55, 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", mapX - 2, mapY - 2, mapW + 4, mapH + 4, 3, 3)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(0.9, 0.8, 0.4)
    love.graphics.printf("World Map  [ M ] to close", 0, mapY - 28, sw, "center")

    local lx = mapX
    local ly = mapY + mapH + 10
    local function legend(r, g, b, label, ox)
        love.graphics.setColor(r, g, b)
        love.graphics.rectangle("fill", lx + ox, ly, 8, 8)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print(label, lx + ox + 10, ly - 1, 0, 0.7, 0.7)
    end
    legend(1, 1, 1, "You", 0)
    legend(0.9, 0.75, 0.3, "Village", 60)
    legend(0.9, 0.8, 0.2, "Chest", 130)
    legend(0.85, 0.3, 1, "Rare", 185)
    legend(1, 0.1, 0.1, "Boss", 225)

    love.graphics.setColor(1, 1, 1)
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