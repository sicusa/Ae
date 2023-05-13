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