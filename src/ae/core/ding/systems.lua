local entity = require("sia.entity")
local system = require("sia.system")

local components = require("ae.core.ding.components")
local name_library = components.name_library
local name = components.name

local name_library_initialize_system = system {
    select = {name_library},
    trigger = {"add"},

    execute = function(world, sched, e)
        if world[name_library] ~= nil then
            print("error: name library already exists")
            return
        end
        world[name_library] = e[name_library]
    end
}

local name_library_uninitiialize_system = system {
    select = {name_library},
    trigger = {"remove"},
    depend = {name_library_initialize_system},

    execute = function(world, sched, e)
        if world[name_library] ~= e[name_library] then
            return
        end
        world[name_library] = nil
    end
}

local recorded_name_state = entity.component(function(value)
    return {value}
end)

local name_record_system = system {
    select = {name},
    trigger = {"add", name.set},
    depend = {
        name_library_initialize_system,
        name_library_uninitiialize_system
    },

    execute = function(world, sched, e)
        local lib = world[name_library]
        if lib == nil then return end

        local name_value = e[name].value
        local state = e[recorded_name_state]

        if state == nil then
            lib[name_value] = e
            e:add_state(recorded_name_state(name_value))
        else
            lib[state[1]] = nil
            lib[name_value] = e
            state[1] = name_value
        end
    end
}

return system {
    name = "ae.ding.systems",
    authors = {"Phlamcenth Sicusa <sicusa@gilatod.art>"},
    description = "Ding systems",
    version = {0, 0, 1},
    children = {
        name_library_initialize_system,
        name_library_uninitiialize_system,
        name_record_system
    }
}