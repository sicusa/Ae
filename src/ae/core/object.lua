local entity = require("sia.entity")
local system = require("sia.system")

local singleton = require("ae.utils.singleton")

---@class ae.object
local object = {}

-- components

---@class ae.object.key_library: sia.component
---@field [any] table<sia.entity, true?>
---@overload fun(value: string): ae.object.key_library
object.key_library = entity.component(function()
    return {}
end)

---@class ae.object.key: sia.component
---@field value any
---@field set sia.command (value: any)
---@overload fun(value: string): ae.object.key
object.key = entity.component(function(value)
    return {
        value = value
    }
end)
:on("set", function(self, value)
    self.value = value
end)

---@class ae.object.kind
---@field parent? ae.object.kind
---@overload fun(parent?: ae.object.kind): ae.object.kind
local kind = {}
object.kind = kind

setmetatable(kind, {
    __call = function(_, parent)
        local instance = setmetatable({}, kind)
        instance.parent = parent
        return instance
    end
})

---@class ae.object.relation_library: sia.component
---@field [ae.object.kind] table<sia.entity, true?>
---@overload fun(): ae.ego.relation_library
object.relation_library = entity.component(function()
    return {}
end)

---@class ae.object.relation.props
---@field source sia.entity
---@field target sia.entity
---@field kind ae.object.kind

---@class ae.object.relation: sia.component
---@field source sia.entity
---@field target sia.entity
---@field kind ae.object.kind
---@overload fun(props: ae.object.relation.props): ae.object.relation
object.relation = entity.component(function(props)
    return {
        source = props.source,
        target = props.target,
        kind = props.kind
    }
end)

-- systems

local key_library = object.key_library
local key = object.key
local relation_library = object.relation_library
local relation = object.relation

local key_library_initialize_system = system {
    name = "ae.object.key_library_initialize_system",
    select = {key_library},
    trigger = {"add"},

    execute = function(world, sched, e)
        singleton.register(world, e, key_library, "key library")
    end
}

local key_library_uninitiialize_system = system {
    name = "ae.object.key_library_uninitiialize_system",
    select = {key_library},
    trigger = {"remove"},
    depend = {key_library_initialize_system},

    execute = function(world, sched, e)
        singleton.unregister(world, e, key_library)
    end
}

local recorded_key_state = entity.component(function(value)
    return {value}
end)

local key_record_system = system {
    name = "ae.object.key_record_system",
    select = {key},
    trigger = {"add", key.set},
    depend = {
        key_library_initialize_system,
        key_library_uninitiialize_system
    },

    execute = function(world, sched, e)
        local lib = singleton.require(world, key_library, "key library")
        if lib == nil then return end

        local key_value = e[key].value
        local state = e[recorded_key_state]

        if state == nil then
            lib[key_value] = e
            e:add_state(recorded_key_state(key_value))
        else
            lib[state[1]] = nil
            lib[key_value] = e
            state[1] = key_value
        end
    end
}

local relation_library_initialize_system = system {
    select = {relation_library},
}

return system {
    name = "ae.object.systems",
    authors = {"Phlamcenth Sicusa <sicusa@gilatod.art>"},
    version = {0, 0, 1},
    children = {
        key_library_initialize_system,
        key_library_uninitiialize_system,
        key_record_system
    }
}