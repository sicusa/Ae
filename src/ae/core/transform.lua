local ffi = require("ffi")

local entity = require("sia.entity")
local system = require("sia.system")
local ffic = require("sia.ffic")

local lume = require("lume")
local vec2 = require("cpml.modules.vec2")

local singleton = require("ae.utils.singleton")

local remove = lume.remove

---@alias ae.vec2 {x: number, y: number}
---@alias ae.vec3 {x: number, y: number, z: number}

---@class ae.transform
local transform = {}

-- components

ffi.cdef[[
    struct ae_transform_position {
        float x, y;
    };
    struct ae_transform_rotation {
        float value;
    };
    struct ae_transform_scale {
        float value;
    };
]]

---@class ae.transform.position: ffi.ctype*
---@field x number
---@field y number
---@field set sia.command (v: vec2)
---@overload fun(pos: ae.vec2): ae.transform.position
transform.position = ffic.struct("ae_transform_position", {
    set = function(self, v)
        self.x = v.x
        self.y = v.y
    end
})

---@class ae.transform.rotation: ffi.ctype*
---@field value number
---@field set sia.command (v: number)
---@overload fun(v: number): ae.transform.rotation
transform.rotation = ffic.struct("ae_transform_rotation", {
    set = function(self, v)
        self.value = v
    end
})

---@class ae.transform.scale: ffi.ctype*
---@field value number
---@field set fun(self: ae.transform.scale, v: number)
---@overload fun(v: number): ae.transform.scale
transform.scale = ffic.struct("ae_transform_scale", {
    set = function(self, v)
        self.value = v
    end
})

-- systems

transform.systems = system {
    name = "ae.transform.systems",
    authors = {"Phlamcenth Sicusa <sicusa@gilatod.art>"},
    version = {0, 0, 1},
    children = {
    }
}

return transform