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
---@param component_type T
---@return T
singleton.acquire = function(world, component_type)
    local instance = world[component_type]
    if instance == nil then
        instance = component_type()
        local e = entity {instance}
        instance.__singleton_entity = e
        world:add(e)
        world[component_type] = instance
        return instance
    end
    return instance
end

---@generic T: sia.component
---@param world sia.world
---@param component_type T
---@return T?
singleton.remove = function(world, component_type)
    local instance = world[component_type]
    if world[component_type] ~= instance then
        return nil
    end
    world[component_type] = nil
    world:remove(instance.__singleton_entity)
    return instance
end

return singleton