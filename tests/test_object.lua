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

ae_world:add(entity {
    object.key_library(),
    object.relation_library()
})

-- test key

print("== test key ==")

local e1 = entity {
    object.key("test 1")
}
local e2 = entity {
    object.key("test 2")
}

ae_world:add(e1)
ae_world:add(e2)
ae_sched:tick();

local lib = ae_world[object.key_library]
print(lib["test 1"], lib["test 2"])

ae_world:modify(e1, object.key.set, "new name")
ae_sched:tick();
print(lib["test 1"], lib["new name"])

-- test relation

print("== test relation ==")

local e1 = entity {}
local e2 = entity {}

local basic_kind = object.kind()
local child_kind = object.kind(basic_kind)

local re = entity {
    object.relation {
        source = e1,
        target = e2,
        kind = child_kind
    }
}

ae_world:add(re)
ae_sched:tick()

local lib = ae_world[object.relation_library]
print(lib[basic_kind][e1])
print(lib[child_kind][e1])