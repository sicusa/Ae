love.filesystem.setRequirePath(
    "?.lua;"..
    "?/init.lua;"..
    "src/?.lua;"..
    "src/?/init.lua;"..
    "third-party/?.lua;"..
    "third-party/?/init.lua;"..
    "third-party/sia/src/?.lua;"..
    "third-party/dyana/src/?.lua;")

local utils = require("cpml.modules.utils")

local binser = require("binser")
local applecake = require("applecake")

local console = require("love-console")
local debugGraph = require("love-debug-graph")

_G.lume = require("lume")
local lurker = require("lurker")

love.keyboard.setKeyRepeat(true)

local rectangle = {
    x = 100, y = 100,
    width = 100, height = 100,
    r = 1, g = 1, b = 1
}
console.ENV.rectangle = rectangle

local fpsGraph
local memGraph
local dtGraph

function love.load()
    fpsGraph = debugGraph:new('fps', 0, 0)
    memGraph = debugGraph:new('mem', 0, 30)
    dtGraph = debugGraph:new('custom', 0, 60)
end

function love.keypressed(key, scancode, isrepeat)
    console.keypressed(key, scancode, isrepeat)
end

function love.textinput(text)
    console.textinput(text)
end

function love.update(dt)
    lurker.update()
    -- Update the graphs
    fpsGraph:update(dt)
    memGraph:update(dt)

    -- Update our custom graph
    dtGraph:update(dt, math.floor(dt * 1000))
    dtGraph.label = 'DT: ' ..  utils.round(dt, 4)

    rectangle.x = love.mouse.getX()
    rectangle.y = love.mouse.getY()

    if love.keyboard.isDown("escape") then
        love.window.close()
    end
end

function love.draw()
    love.graphics.setColor(rectangle.r, rectangle.g, rectangle.b, 1)
    love.graphics.rectangle("fill", rectangle.x, rectangle.y,
        rectangle.width, rectangle.height)

    console.draw()

    -- Draw graphs
    fpsGraph:draw()
    memGraph:draw()
    dtGraph:draw()
end
