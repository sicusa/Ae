local entity = require("sia.entity")

---@class ae.ding.components
local components = {}

---@class ae.ding.name_library: sia.component
---@field [string] sia.entity
---@overload fun(value: string): ae.ding.name_library
components.name_library = entity.component(function()
    return {}
end)

---@class ae.ding.name: sia.component
---@field value string
---@field set sia.command (value: string)
---@overload fun(value: string): ae.ding.name
components.name = entity.component(function(value)
    return {
        value = value
    }
end)
:on("set", function(self, value)
    self.value = value
end)

return components