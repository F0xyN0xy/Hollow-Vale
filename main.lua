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

    enemies            = spawnEnemies(world)
    boss               = Boss:new(10, 10)
    npcs               = {}

    local ok, bgm      = pcall(love.audio.newSource, "assets/Sound/HollowVale.wav", "stream")
    if ok then
        bgm:setLooping(true); bgm:setVolume(0.4); bgm:play()
        overworldMusic = bgm
    end

    gameState = "playing"
    victoryTimer = 0
end

function spawnEnemies(world)
    local list = {}
    local T    = World.T
    math.randomseed(world.seed + 777)
    local kinds = { "orc", "greenslime", "redslime", "bat" }
    local count = 0
    for r = 3, world.rows - 2 do
        for c = 3, world.cols - 2 do
            if world.map[r][c] == T.GRASS and count < 14 then
                if math.random() < 0.015 then
                    table.insert(list, Enemy:new(kinds[math.random(#kinds)], c, r))
                    count = count + 1
                end
            end
        end
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
    for _, npc in ipairs(npcs) do npc:update(dt, player) end

    local atkBox = player:getAttackBox()

    for i = #enemies, 1, -1 do
        local e = enemies[i]
        e:update(dt, player, world)
        if atkBox and not e.dead then
            local ts = TILE_SIZE * SCALE
            if atkBox.x < e.x + ts and atkBox.x + atkBox.w > e.x and
                atkBox.y < e.y + ts and atkBox.y + atkBox.h > e.y then
                e:takeDamage(1)
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
                boss:takeDamage(1)
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
        if key == "return" or key == "space" then
            love.load()
        end
        return
    end

    if key == "space" or key == "z" then player:attack() end
    if key == "e" then
        local item = world:tryOpenChest(player)
        if item then
            player:addItem(item)
        else
            for _, npc in ipairs(npcs) do
                if npc:tryTalk(player) then break end
            end
        end
    end
    if key == "r" then
        world              = World:new()
        player.x, player.y = world:findSpawn()
        enemies            = spawnEnemies(world)
        boss               = Boss:new(10, 10)
    end
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

    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.print("WASD move  |  Space/Z attack  |  E open/talk  |  R new world",
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
    love.graphics.printf("Victory", 0, sh / 2 - 40, sw, "center")

    if victoryTimer > 1.5 then
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.printf("The Skeleton Lord has been defeated.\n\nPress Space to play again",
            0, sh / 2 + 10, sw, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

function drawGameOver()
    local sw, sh = love.graphics.getDimensions()
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, sw, sh)
    love.graphics.setColor(0.85, 0.2, 0.2)
    love.graphics.printf("You died", 0, sh / 2 - 30, sw, "center")
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.printf("Press Space to try again", 0, sh / 2 + 20, sw, "center")
    love.graphics.setColor(1, 1, 1)
end
