local entity = require("sia.entity")

---@class ae.singleton
local singleton = {}

---@generic T: sia.component
---@param world sia.world
---@param component_type T
---@param name string
---@return T?
singleton.get = function(world, component_type, name)
    local instance = world[component_type]
    if instance == nil then
        print("error: "..name.." singleton not found")
        return nil
    end
    return instance
end

---@generic T: sia.component
---@param world sia.world
---@param entity sia.entity
---@param component_type T
---@param name string
---@return T?
singleton.register = function(world, entity, component_type, name)
    if world[component_type] ~= nil then
        print("error: "..name.." singleton already exists")
        return nil
    end
    local instance = entity[component_type]
    world[component_type] = instance
    return instance
end

---@generic T: sia.component
---@param world sia.world
---@param entity sia.entity
---@param component_type T
---@return T?
singleton.unregister = function(world, entity, component_type)
    local instance = entity[component_type]
    if world[component_type] ~= instance then
        return nil
    end
    world[component_type] = nil
    return instance
end

return singleton