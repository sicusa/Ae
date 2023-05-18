local entity = require("sia.entity")

---@class ae.ding.components
local components = {}

---@class ae.ding.key_library: sia.component
---@field [any] table<sia.entity, true?>
---@overload fun(value: string): ae.ding.key_library
components.key_library = entity.component(function()
    return {}
end)

---@class ae.ding.name: sia.component
---@field value any
---@field set sia.command (value: any)
---@overload fun(value: string): ae.ding.name
components.key = entity.component(function(value)
    return {
        value = value
    }
end)
:on("set", function(self, value)
    self.value = value
end)

---@class ae.ego.relation_library: sia.component
---@overload fun(): ae.ego.relation_library
components.relation_library = entity.component(function()
    return {}
end)

---@class ae.ego.relation.props
---@field source sia.entity
---@field target sia.entity
---@field category any

---@class ae.ego.relation: sia.component
---@field source sia.entity
---@field target sia.entity
---@field category any
---@overload fun(props: ae.ego.relation.props): ae.ego.relation
components.relation = entity.component(function(props)
    return {
        source = props.source,
        target = props.target,
        category = props.category
    }
end)


return components