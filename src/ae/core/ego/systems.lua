local entity = require("sia.entity")
local system = require("sia.system")

local components = require("ae.core.ego.components")
local ownership_library = components.ownership_library
local ownership = components.ownership

---@class ae.ego.systems
local systems = {}

systems.ownership_library_initialize_system = system {
    select = {ownership_library},
    trigger = {"add"},

    execute = function(world, sched, e)
        local lib = e[ownership_library]
        if world[ownership_library] ~= nil then
            print("error: ownership library already exists")
            world:remove(e)
            return
        end
        world[ownership_library] = lib
    end
}

systems.ownership_library_uninitialize_system = system {
    select = {ownership_library},
    trigger = {"remove"},

    execute = function(world, sched, e)
        local lib = e[ownership_library]
        if world[ownership_library] ~= lib then
            return
        end
        world[ownership_library] = nil
    end
}

systems.ownership_record_system = system {
    select = {ownership},
    
}

return systems