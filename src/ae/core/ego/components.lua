local entity = require("sia.entity")

---@class ae.ego.components
local components = {}

---@class ae.ego.noesis.config
---@field quality sia.entity
---@field matter sia.entity

---@class ae.ego.noesis: sia.component, ae.ego.noesis.config
---@overload fun(config: ae.ego.noesis.config)
components.noesis = entity.component(function(config)
    return {
        quality = config.quality,
        matter = config.matter
    }
end)

return components