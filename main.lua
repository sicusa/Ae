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

local vec2 = require("cpml.modules.vec2")
local entity = require("sia.entity")
local world = require("sia.world")
local scheduler = require("sia.scheduler")

local welt = require("ae.core.welt")
local ding = require("ae.core.ding")

local ae_world = world()
local ae_sched = scheduler()
ae_world.scheduler = ae_sched

welt.systems:register(ae_world, ae_sched);
ding.systems:register(ae_world, ae_sched);

love.keyboard.setKeyRepeat(true)

ae_world:add(entity {
    welt.constraint_library()
})

local space = welt.space {
    grid_scale = 50
}
local space_e = entity {
    space
}

local player = entity {
    welt.in_space(space_e),
    welt.position(0, 0)
}
ae_world:add(player)

local pivot = entity {
    welt.position(0, 0)
}
ae_world:add(entity {
    welt.constraint {
        source = pivot,
        target = player,
        position_offset = vec2.new(50, 50)
    }
})

local function create_obstacle(x, y)
    return entity {
        welt.position(x * space.grid_scale, y * space.grid_scale),
        welt.in_space(space_e),
        welt.obstacle()
    }
end

ae_world:add(create_obstacle(3, 5))
ae_world:add(create_obstacle(3, 4))
ae_world:add(create_obstacle(3, 3))
ae_world:add(create_obstacle(3, 2))
ae_world:add(create_obstacle(3, 1))

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

local motion_vec = welt.position(0, 0)

function love.update(dt)
    --lurker.update()
    if love.keyboard.isDown("escape") then
        love.window.close()
        return
    end

    motion_vec.x, motion_vec.y = love.mouse.getPosition()
    ae_world:modify(pivot, welt.position.set, motion_vec)

    --[[
    motion_vec.x, motion_vec.y = get_motion_vec()
    ae_world:modify(pivot, welt.position.set,
        vec2.add(
            pivot[welt.position],
            vec2.scale(motion_vec, dt * 200)))]]
    ae_sched:tick()
end

function love.draw()
    console.draw()

    local p = player[welt.position]
    love.graphics.rectangle("fill", p.x, p.y, 50, 50);

    local x, y = space:get_object_grid_point(player)
    love.graphics.print("Grid: "..x..", "..y)
end
