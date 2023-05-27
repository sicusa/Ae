require("tests.common")

local vec2 = require("cpml.modules.vec2")
local entity = require("sia.entity")
local world = require("sia.world")
local scheduler = require("sia.scheduler")

local space = require("ae.core.space")

local ae_world = world()
local ae_sched = scheduler()
ae_world.scheduler = ae_sched

space.systems:register(ae_world, ae_sched)

-- test node

print("== node ==")

local e1 = entity {
    space.node(),
    space.position(2, 2),
    space.rotation(0)
}
local e2 = entity {
    space.node(e1),
    space.position(0, 0)
}
local e3 = entity {
    space.node(e2),
    space.position(1, 1)
}

ae_world:add(e3)
ae_sched:tick()

ae_world:modify(e2, space.position.set, space.position(1, 4))
ae_sched:tick()

local e2_trans = e2[space.node].world_transform
local e3_trans = e3[space.node].world_transform
print(e2_trans:transformPoint(0, 0))
print(e3_trans:transformPoint(0, 0))

ae_world:modify(e1, space.position.set, space.position(7, 4))
ae_sched:tick()
print(e2_trans:transformPoint(0, 0))
print(e3_trans:transformPoint(0, 0))

-- test map

print("== map ==")

local map = space.map {}
local map_e = entity {
    map
}

local e1 = entity {
    space.in_map(map_e),
    space.position(3, 13)
}

ae_world:add(e1)
ae_sched:tick()

print(e1)
print(map:get_object_in_grid(3, 13))

ae_world:modify(e1, space.position.set, vec2.new(7, 149))
ae_sched:tick()

print("moved")
print(map:get_object_in_grid(3, 13))
print(map:get_object_in_grid(7, 149))