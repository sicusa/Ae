require("tests.common")

local vec2 = require("cpml.modules.vec2")
local entity = require("sia.entity")
local world = require("sia.world")
local scheduler = require("sia.scheduler")

local welt = require("ae.core.welt")

local ae_world = world()
local ae_sched = scheduler()
ae_world.scheduler = ae_sched

welt.systems:register(ae_world, ae_sched);

-- transform

print("== transform ==")

ae_world:add(entity {
    welt.constraint_library {}
})

local e1 = entity {
    welt.position {x = 1, y = 2}
}
local e2 = entity {
    welt.position {x = 3, y = 4}
}
local ce = entity {
    welt.constraint {
        source = e1,
        target = e2,
        position_offset = {x = 2, y = 2}
    }
}
ae_world:add(ce)
ae_sched:tick();
print(ae_world:contains(ce), ae_world:contains(e1))

ae_world:modify(e1, welt.position.set, {x = 2, y = 1})
ae_sched:tick();
print(vec2.unpack(e2[welt.position]))

ae_world:remove(e2)
ae_sched:tick();
ae_world:modify(e1, welt.position.set, {x = 2, y = 2})
ae_sched:tick();
print(vec2.unpack(e2[welt.position]))

-- space

print("== space ==")

local space = welt.space {}
local space_e = entity {
    space
}

local e1 = entity {
    welt.in_space(space_e),
    welt.position(3, 13)
}

ae_world:add(e1)
ae_sched:tick()

print(e1)
print(space:get_object_in_grid(3, 13))

ae_world:modify(e1, welt.position.set, vec2.new(7, 149))
ae_sched:tick()

print("moved")
print(space:get_object_in_grid(3, 13))
print(space:get_object_in_grid(7, 149))