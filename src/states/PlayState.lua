--[[
    CS50 2D
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    -- in playstate, ball is a list
    self.ball = {}
    -- insert start ball as item 1
    table.insert(self.ball, params.ball)
    self.level = params.level

    self.recoverPoints = params.recoverPoints

    -- give ball random starting velocity
    self.ball[1].dx = math.random(-200, 200)
    self.ball[1].dy = math.random(-50, -60)

    -- set powerup spawn information
    -- initialise timer
    self.powerUpTime = 0
    -- create empty list
    self.powerUpList = {}
    -- set time bewteen spawns (seconds)
    self.powerUpSchedule = 5
end

function PlayState:update(dt)
-- almost the whole of update need to loop through all the balls
-- better solution would be to move lots of the ball checking code to ball:upate
-- probably not necessary is this situation as not really tha much going on
-- and looping rond nalls is ot going have much impact on perseived speed
-- of everything else


-- lets loop through balls
    for k, ballToCheck in ipairs(self.ball) do
        
        if self.paused then
            if love.keyboard.wasPressed('space') then
                self.paused = false
                gSounds['pause']:play()
            else
                return
            end
        elseif love.keyboard.wasPressed('space') then
            self.paused = true
            gSounds['pause']:play()
            return
        end

        -- update positions based on velocity
        self.paddle:update(dt)
        
        ballToCheck:update(dt)
        if ballToCheck:collides(self.paddle) then
            -- raise ball above paddle in case it goes below it, then reverse dy
            ballToCheck.y = self.paddle.y - 8
            ballToCheck.dy = -ballToCheck.dy

            --
            -- tweak angle of bounce based on where it hits the paddle
            --

            local isPaddleMovingLeft = self.paddle.dx < 0
            local isPaddleMovingRight = self.paddle.dx > 0
            local paddleCenter = self.paddle.x + self.paddle.width / 2

            -- adjustable values for the feel of bounce speed/angle
            local startingBounceDX = 50
            local bounceAngleMultiplier = 8

            -- if we hit the paddle on its left side while moving left...
            if ballToCheck.x < paddleCenter and isPaddleMovingLeft then
                local ballOffset = paddleCenter - ballToCheck.x
                self.ball.dx = -startingBounceDX - bounceAngleMultiplier * ballOffset

            -- else if we hit the paddle on its right side while moving right...
            elseif ballToCheck.x > paddleCenter and isPaddleMovingRight then
                local ballOffset = ballToCheck.x - paddleCenter
                ballToCheck.dx = startingBounceDX + bounceAngleMultiplier * ballOffset
            end

            gSounds['paddle-hit']:play()
        end
    
        -- detect collision across all bricks with the ball
        for k, brick in pairs(self.bricks) do
            -- we need to check collision for each ball
            
            -- only check collision if we're in play
            if brick.inPlay and ballToCheck:collides(brick) then

                -- add to score
                self.score = self.score + (brick.tier * 200 + brick.color * 25)

                -- trigger the brick's hit function, which removes it from play
                brick:hit()

                -- if we have enough points, recover a point of health
                if self.score > self.recoverPoints then
                    -- can't go above 3 health
                    self.health = math.min(3, self.health + 1)

                    -- multiply recover points by 2
                    self.recoverPoints = math.min(100000, self.recoverPoints * 2)

                    -- play recover sound effect
                    gSounds['recover']:play()
                end

                -- go to our victory screen if there are no more bricks left
                if self:checkVictory() then
                    gSounds['victory']:play()

                    gStateMachine:change('victory', {
                        level = self.level,
                        paddle = self.paddle,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        -- only pass ball 1 to next state
                        ball = self.ball[1],
                        recoverPoints = self.recoverPoints
                        })
                end

                --
                -- collision code for bricks
                --
                -- we check to see how much we overlap on the brick between X and Y axes;
                -- the delta between the centers of the brick and ball will help us pinpoint
                -- which side, and then how far in the ball has overlapped will determine
                -- whether to prioritize a Y bounce or an X bounce

                local BALL_RADIUS = 4
                local BRICK_W, BRICK_H = brick.width, brick.height

                -- centers of X and Y of our brick and ball
                local cxB, cyB = brick.x + BRICK_W / 2, brick.y + BRICK_H / 2
                local cxb, cyb = ballToCheck.x + BALL_RADIUS, ballToCheck.y + BALL_RADIUS

                -- signed collision offsets between brick and ball
                local ox = cxB - cxb
                local oy = cyB - cyb

                -- penetration depth of the ball on X and Y;
                -- add half-extents of brick and ball, then subtract
                -- amount of overlap on that axis; the higher penetration
                -- depth is the prioritized collision and axis of bounce
                local px = BRICK_W / 2 + BALL_RADIUS - math.abs(ox)
                local py = BRICK_H / 2 + BALL_RADIUS - math.abs(oy)

                if px < py then
                    ballToCheck.dx = -ballToCheck.dx
                    ballToCheck.x = ballToCheck.x + (ox > 0 and -px or px)
                else
                    ballToCheck.dy = -ballToCheck.dy
                    ballToCheck.y = ballToCheck.y + (oy > 0 and -py or py)
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(ballToCheck.dy) < 150 then
                    ballToCheck.dy = ballToCheck.dy * 1.02
                end

                -- only allow colliding with one brick, for corners
                break
            end
        end
    end

    -- if ball goes below bounds, revert to serve state and decrease health
    -- only if it was last ball
    -- othewsie just remove ball from table
    if #self.ball == 1 then
        if self.ball[1].y >= VIRTUAL_HEIGHT then
            self.health = self.health - 1
            gSounds['hurt']:play()

            if self.health == 0 then
                gStateMachine:change('game-over', {
                    score = self.score,
                    highScores = self.highScores
                })
            else
                -- reduce size of paddle 
                -- only if larger than 2 (original size)
                if self.paddle.size > 2 then 
                    self.paddle.size = self.paddle.size - 1
                    self.paddle.width = self.paddle.width - 32
                end
                gStateMachine:change('serve', {
                    paddle = self.paddle,
                    bricks = self.bricks,
                    health = self.health,
                    score = self.score,
                    highScores = self.highScores,
                    level = self.level,
                    recoverPoints = self.recoverPoints
                })
            end
        end
    else
        -- check all balls
        for k, ballToCheck in ipairs(self.ball) do
            if ballToCheck.y >= VIRTUAL_HEIGHT then
                gSounds['hurt']:play()
                table.remove(self.ball, k)
            end
        end
    end
    
        -- update any active powerups
    for k, powerUpToUpdate in ipairs(self.powerUpList) do
        -- check for any collisions
        -- collison with ball kils powerup
        for j, ballToCheck in ipairs(self.ball) do
            if ballToCheck:collides(powerUpToUpdate) and powerUpToUpdate.inPlay then
                -- play sad sound
                gSounds['powerdown']:play()
                powerUpToUpdate:hit()
                -- kill the object
                -- table.remove(self.powerUpList, j)
                powerUpToUpdate.inPlay = false
            end

        end
        -- collison with bat mean powerup (or down) activated
        -- collide will return flase, or the powerup type if collided
        local powerUpAchieved = powerUpToUpdate:collides(self.paddle)
        if powerUpToUpdate.inPlay and powerUpAchieved then
            gSounds['powerup']:play()
            -- kill the object
            powerUpToUpdate:hit()
            powerUpToUpdate.inPlay = false
            --table.remove(self.powerUpList, k)
            -- should have returned the type
            if powerUpAchieved == 'ExtraBall' then
                -- spawn a new ball
                local newBall = Ball()
                newBall.skin = math.random(7)
                newBall:reset()
                -- give ball random starting velocity
                newBall.dx = math.random(-200, 200)
                newBall.dy = math.random(-50, -60)
                table.insert(self.ball, newBall)
            end
            if powerUpAchieved == 'BiggerBat' then
                if self.paddle.size < 4 then 
                    self.paddle.size = self.paddle.size + 1
                    self.paddle.width = self.paddle.width + 32
                end
            end
            if powerUpAchieved == 'SmallerBat' then
                if self.paddle.size > 1 then 
                    self.paddle.size = self.paddle.size - 1
                    self.paddle.width = self.paddle.width - 32
                end
            end
            
        end
        
        -- powerUps:Update will return true if powerup still in play
        -- and false if not
        if not powerUpToUpdate:update(dt) then
            -- play sad sound
            gSounds['powerdown']:play()
            -- kill the object
            -- table.remove(self.powerUpList, k)
            powerUpToUpdate.inPlay = false
        end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    -- clean up PU table
    for k = #self.powerUpList, 1, -1  do
        if not self.powerUpList[k].inPlay then
            if self.powerUpList[k].psystem:getCount() == 0  then
                table.remove(self.powerUpList, k)
            end
        end
    end

    -- powerup system
    -- 1:  generate the powerups
    -- we are determining the type here in case we need to have more control
    -- for the moment, a random powerup each spawn
    -- are we ready to spawn?
    self.powerUpTime = self.powerUpTime + dt
    if self.powerUpTime > self.powerUpSchedule then
        -- lets spawn!
        local powerUpType = math.random(1,4)
        local newPowerUp
        if powerUpType == 1 then
            -- create the powerup object
            newPowerUp = PowerUp('ExtraBall')
            -- add the object to the list of powerups
            table.insert(self.powerUpList, newPowerUp)
            gSounds['powerup']:play()
        elseif powerUpType == 2 then 
            -- create the powerup object
            newPowerUp = PowerUp('Key')
            -- add the object to the list of powerups
            table.insert(self.powerUpList, newPowerUp)
            gSounds['powerup']:play()
        elseif powerUpType == 3 then
            -- create the powerup object
            newPowerUp = PowerUp('BiggerBat')
            -- add the object to the list of powerups
            table.insert(self.powerUpList, newPowerUp)
            gSounds['powerup']:play()
        elseif powerUpType == 4 then
            -- create the powerup object
            newPowerUp = PowerUp('SmallerBat')
            -- add the object to the list of powerups
            table.insert(self.powerUpList, newPowerUp)
            gSounds['powerup']:play()
        
        -- no other options but we do each explicit to avoid any bugs.
        -- so if for any reason powerUpType is not 1,2, or 3 then no powerup
        end
    self.powerUpTime = 0
    end


    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all brick particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()
    
    -- render all balls
    for k, ballToDraw in ipairs(self.ball) do
        ballToDraw:render()
    end

    -- render any active powerups or their particles
    for k, powerUpToDraw in ipairs(self.powerUpList) do
        powerUpToDraw:render()
        powerUpToDraw:renderParticles()
    end

    RenderScore(self.score)
    RenderHealth(self.health)

    --debug
    love.graphics.print('PUs: ' .. tostring(#self.powerUpList), 5, 15)
    love.graphics.print('BLs: ' .. tostring(#self.ball), 5, 25)
    
    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end
    end

    return true
end
