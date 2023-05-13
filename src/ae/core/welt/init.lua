local lume = require("lume")

---@class ae.welt: ae.welt.components
---@field systems sia.system
local welt = lume.merge(
    require("ae.core.welt.components"),
    {systems = require('ae.core.welt.systems')})

return welt