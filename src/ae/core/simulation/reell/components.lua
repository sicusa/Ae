local entity = require("sia.entity")

---@class ae.reell.components
local components = {}

---@class ae.reell.components.ego.config
---@field identifier string

---@class ae.reell.components.ego
---@field identifier number
---@overload fun(config: ae.reell.components.ego.config): ae.reell.components.ego
components.ego = entity.component(function(config)
    return {
        identifier = assert(config.identifier)
    }
end) --[[@as ae.reell.components.ego]]

return components