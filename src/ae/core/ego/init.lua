local lume = require("lume")

---@class ae.ego : ae.ego.components
return lume.merge(
    require("ae.core.ego.components"),
    require("ae.core.ego.systems"))