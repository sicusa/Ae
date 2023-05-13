love.filesystem.setRequirePath(
    "?.lua;" ..
    "?/init.lua;" ..
    "src/?.lua;" ..
    "src/?/init.lua;" ..
    "third-party/?.lua;" ..
    "third-party/?/init.lua;" ..
    "third-party/sia/src/?.lua;" ..
    "third-party/dyana/src/?.lua;")

_G.lume = require("lume")

local console = require("love-console")
--local lurker = require("lurker")

love.keyboard.setKeyRepeat(true)

function love.load()
end

function love.keypressed(key, scancode, isrepeat)
    console.keypressed(key, scancode, isrepeat)
end

function love.textinput(text)
    console.textinput(text)
end

function love.update(dt)
    --lurker.update()
    if love.keyboard.isDown("escape") then
        love.window.close()
    end
end

function love.draw()
    console.draw()
end
