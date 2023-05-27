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

--local lurker = require("lurker")
local console = require("love-console")
local vec2 = require("cpml.modules.vec2")

local entity = require("sia.entity")
local world = require("sia.world")
local scheduler = require("sia.scheduler")

require("tests.test_space")

function love.load()
end

function love.keypressed(key, scancode, isrepeat)
    console.keypressed(key, scancode, isrepeat)
end

function love.textinput(text)
    console.textinput(text)
end

---@return number
---@return number
local function get_motion_vec()
    local h
    if love.keyboard.isDown("right") then
        h = 1
    elseif love.keyboard.isDown("left") then
        h = -1
    else
        h = 0
    end

    local v
    if love.keyboard.isDown("up") then
        v = -1
    elseif love.keyboard.isDown("down") then
        v = 1
    else
        v = 0
    end

    return h, v
end

function love.update(dt)
    --lurker.update()
    if love.keyboard.isDown("escape") then
        love.window.close()
        return
    end
end

function love.draw()
    console.draw()
end
