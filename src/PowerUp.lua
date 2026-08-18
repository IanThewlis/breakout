--[[
    -- PowerUp Class --

    Represents a poowerup that will randomnly spawn and then fall towards
    the floor.  If it collides with the bat then the game change in some way
    
]]

PowerUp = Class{}

function PowerUp:init(type)
    -- Initialise the powerup according to type
    -- type options are:
    -- ExtraBall - this will remain until lost
    -- BiggerBat - this will remain for x returns.
    -- Key - Once you have the key you have it
    -- we can set x during init
    self.x = math.random(10, VIRTUAL_WIDTH - 10)
    -- spawn at row 4
    self.y = 4
    -- set momentum, start slow (it will speed up as it gets nearer bottom]
    self.dy = 0

    self.type = type
    -- now set the imageid for this instance
        -- key: 154
        -- extraball: 153
        -- biggerbat: 149
    if type == 'ExtraBall' then
        self.imageid = 153
    elseif type == 'Key' then
        self.imageid = 154
    elseif type == 'BiggerBat' then
        self.imageid = 149
    elseif type == 'SmallerBat' then
        self.imageid = 150
        
    end

    -- we need a width and hieght
    self.width = 16
    self.height = 16

end

function PowerUp:collides(target)
    -- based on ball class, it will check if it has collided with Paddle
    -- so target will always be Paddle
    -- first, check to see if the left edge of either is farther to the right
    -- than the right edge of the other
    if self.x > target.x + target.width or target.x > self.x + self.width then
        return false
    end

    -- then check to see if the bottom edge of either is higher than the top
    -- edge of the other
    if self.y > target.y + target.height or target.y > self.y + self.height then
        return false
    end

    -- if the above aren't true, they're overlapping
    -- so return the powerup type
    return self.type
end

function PowerUp:reset()
    -- dont know if we ever need to reset

    --self.x = VIRTUAL_WIDTH / 2 - 2
    --self.y = VIRTUAL_HEIGHT / 2 - 2
    --self.dx = 0
    --self.dy = 0
end

function PowerUp:update(dt)
    -- based on ball class
    
    -- this will check if the powerup has reached the bottom of the screen
    -- self.y > VIRTUAL_HEIGHT
    -- if it has we want a sad sound
    
    -- drop powerup by momentum
    -- self.x = self.x
    self.y = self.y + ((self.dy * dt))
    self.dy  = self.dy + dt

    -- has it reached bottom of screen
    if self.y > VIRTUAL_HEIGHT - 16 then
        -- display explosion
        -- play sad sound
        return false
    end
    return true
end

function PowerUp:render()
    -- gTexture is our global texture for all blocks
    -- gBallFrames is a table of quads mapping to each individual ball skin in the texture
    love.graphics.draw(gTextures['main'], gFrames['powerups'][self.imageid], self.x, self.y)
    -- debug
    love.graphics.print(self.type, self.x, self.y - 3)

end
