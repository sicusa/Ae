local lume = require("lume")

---@class ae.reell : ae.reell.components
return lume.merge(
    require("ae.core.simulation.reell.components"),
    require("ae.core.simulation.reell.systems"))