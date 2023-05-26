require("tests.common")

local vec2 = require("cpml.modules.vec2")
local entity = require("sia.entity")
local world = require("sia.world")
local scheduler = require("sia.scheduler")

local transform = require("ae.core.transform")
local space = require("ae.core.space")

local ae_world = world()
local ae_sched = scheduler()
ae_world.scheduler = ae_sched

transform.systems:register(ae_world, ae_sched)
space.systems:register(ae_world, ae_sched)

-- test map

print("== map ==")

local map = space.map {}
local map_e = entity {
    map
}

local e1 = entity {
    space.in_map(map_e),
    transform.position(3, 13)
}

ae_world:add(e1)
ae_sched:tick()

print(e1)
print(map:get_object_in_grid(3, 13))

ae_world:modify(e1, transform.position.set, vec2.new(7, 149))
ae_sched:tick()

print("moved")
print(map:get_object_in_grid(3, 13))
print(map:get_object_in_grid(7, 149))