require("tests.common")

local vec2 = require("cpml.modules.vec2")
local entity = require("sia.entity")
local world = require("sia.world")
local scheduler = require("sia.scheduler")

local object = require("ae.core.object")

local ae_world = world()
local ae_sched = scheduler()
ae_world.scheduler = ae_sched

object.systems:register(ae_world, ae_sched);

-- test name

print("== test name ==")

local e1 = entity {
    object.name("test 1")
}
local e2 = entity {
    object.name("test 2")
}

ae_world:add(e1)
ae_world:add(e2)
ae_sched:tick();

local lib = ae_world[object.name_library]
print(lib["test 1"], lib["test 2"])

ae_world:modify(e1, object.name.set, "new name")
ae_sched:tick();
print(lib["test 1"], lib["new name"])

-- test relation

print("== test monitor ==")

local e1 = entity {
    object.monitor {
        remove = function()
            print("e1 remove")
        end
    }
}
ae_world:add(e1)

local e2 = entity {}
local m = entity {
    object.monitor {
        target = e2,
        tick = function()
            print("e2 tick")
        end,
        add = function()
            print("e2 add")
        end,
        remove = function()
            print("e2 remove")
        end
    }
}
ae_world:add(m)

ae_sched:tick()
ae_sched:tick()

ae_world:remove(e1)
ae_world:remove(e2)
ae_world:add(e2)
ae_world:remove(e2)
ae_world:remove(m)

ae_sched:tick()
ae_world:add(e2)