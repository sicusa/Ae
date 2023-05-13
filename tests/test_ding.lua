require("tests.common")

local vec2 = require("cpml.modules.vec2")
local entity = require("sia.entity")
local world = require("sia.world")
local scheduler = require("sia.scheduler")

local ding = require("ae.core.ding")

local ae_world = world()
local ae_sched = scheduler()
ae_world.scheduler = ae_sched

ding.systems:register(ae_world, ae_sched);

ae_world:add(entity {
    ding.name_library()
})

local e1 = entity {
    ding.name("test 1")
}
local e2 = entity {
    ding.name("test 2")
}

ae_world:add(e1)
ae_world:add(e2)
ae_sched:tick();

local lib = ae_world[ding.name_library]
print(lib["test 1"], lib["test 2"])

ae_world:modify(e1, ding.name.set, "new name")
ae_sched:tick();
print(lib["test 1"], lib["new name"])