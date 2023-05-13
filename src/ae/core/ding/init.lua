local lume = require("lume")

---@class ae.ding : ae.ding.components
---@field systems sia.system
local ding = lume.merge(
    require("ae.core.ding.components"),
    {systems = require("ae.core.ding.systems")})

return ding