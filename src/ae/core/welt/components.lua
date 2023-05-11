local ffi = require("ffi")

local entity = require("sia.entity")
local ffic = require("sia.ffic")

ffi.cdef[[
    struct ae_welt_position {
        float x, y;
    }
    struct ae_welt_rotation {
        float value;
    }
    struct ae_welt_scale {
        float value;
    }
]]

---@alias ae.welt.vec2 {x: number, y: number}

---@class ae.welt.components
local components = {}

---@class ae.welt.components.world
---@overload fun(): ae.welt.components.world
local world = entity.component(function()
    return {}
end) --[[@as ae.welt.components.world]]

---@class ae.welt.components.position
---@operator call(): ae.welt.components.position
local position = ffic.struct("ae_welt_position", {
    set = function(self, v)
        self.x = v.x
        self.y = v.y
    end
}) --[[@as ae.welt.components.position]]

local rotation = ffic.struct("ae_welt_rotation", {
    set = function(self, v)
        self.value = v
    end
})

return components;