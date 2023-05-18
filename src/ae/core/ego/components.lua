local entity = require("sia.entity")

---@class ae.ego.components
local components = {}

---@class ae.ego.noesis.props
---@field quality sia.entity
---@field matter sia.entity

---@class ae.ego.noesis: sia.component
---@field quality sia.entity
---@field matter sia.entity
---@overload fun(props: ae.ego.noesis.props): ae.ego.noesis
components.noesis = entity.component(function(props)
    return {
        quality = props.quality,
        matter = props.matter
    }
end)

return components