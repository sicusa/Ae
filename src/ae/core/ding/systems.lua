local entity = require("sia.entity")
local system = require("sia.system")

local components = require("ae.core.ding.components")
local key_library = components.key_library
local key = components.key

local key_library_initialize_system = system {
    select = {key_library},
    trigger = {"add"},

    execute = function(world, sched, e)
        if world[key_library] ~= nil then
            print("error: key library already exists")
            return
        end
        world[key_library] = e[key_library]
    end
}

local key_library_uninitiialize_system = system {
    select = {key_library},
    trigger = {"remove"},
    depend = {key_library_initialize_system},

    execute = function(world, sched, e)
        if world[key_library] ~= e[key_library] then
            return
        end
        world[key_library] = nil
    end
}

local recorded_key_state = entity.component(function(value)
    return {value}
end)

local key_record_system = system {
    select = {key},
    trigger = {"add", key.set},
    depend = {
        key_library_initialize_system,
        key_library_uninitiialize_system
    },

    execute = function(world, sched, e)
        local lib = world[key_library]
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

return system {
    name = "ae.ding.systems",
    authors = {"Phlamcenth Sicusa <sicusa@gilatod.art>"},
    description = "Ding systems",
    version = {0, 0, 1},
    children = {
        key_library_initialize_system,
        key_library_uninitiialize_system,
        key_record_system
    }
}