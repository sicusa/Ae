local ffi = require("ffi")

local entity = require("sia.entity")
local ffic = require("sia.ffic")

ffi.cdef[[
    struct ae_welt_position {
        float x, y;
    };
    struct ae_welt_rotation {
        float value;
    };
    struct ae_welt_scale {
        float value;
    };
]]

---@alias ae.welt.vec2 {x: number, y: number}

---@class ae.welt.components
local components = {}

-- transform

---@class ae.welt.position: ffi.ctype*
---@field x number
---@field y number
---@field set sia.command (v: vec2)
---@overload fun(pos: ae.welt.vec2): ae.welt.position
components.position = ffic.struct("ae_welt_position", {
    set = function(self, v)
        self.x = v.x
        self.y = v.y
    end
})

---@class ae.welt.rotation: ffi.ctype*
---@field value number
---@field set sia.command (v: number)
---@overload fun(v: number): ae.welt.rotation
components.rotation = ffic.struct("ae_welt_rotation", {
    set = function(self, v)
        self.value = v
    end
})

---@class ae.welt.scale: ffi.ctype*
---@field value number
---@field set fun(self: ae.welt.scale, v: number)
---@overload fun(v: number): ae.welt.scale
components.scale = ffic.struct("ae_welt_scale", {
    set = function(self, v)
        self.value = v
    end
})

---@class ae.welt.constraint.config
---@field source sia.entity
---@field target sia.entity
---@field position_offset? ae.welt.vec2
---@field rotation_offset? number
---@field scale_offset? number

---@class ae.welt.constraint: sia.component, ae.welt.constraint.config
---@field set_position_offset sia.command (v: vec2)
---@field set_rotation_offset sia.command (v: number)
---@field set_scale_offset sia.command (v: number)
---@overload fun(config: ae.welt.constraint.config): ae.welt.constraint
components.constraint = entity.component(function(config)
    return {
        source = config.source,
        target = config.target,
        position_offset = config.position_offset,
        rotation_offset = config.rotation_offset,
        scale_offset = config.scale_offset
    }
end)
:on("set_position_offset", function(self, v)
    self.position_offset = v
end)
:on("set_rotation_offset", function(self, v)
    self.rotation_offset = v
end)
:on("set_scale_offset", function(self, v)
    self.scale_offset = v
end)

---@class ae.welt.constraint_library: sia.component
---@field [sia.entity] ae.welt.constraint[]
---@overload fun(): ae.welt.constraint_library
components.constraint_library = entity.component(function()
    return {}
end)

-- world

---@class ae.welt.space.config
---@field grid_scale? number

---@class ae.welt.space: sia.component
---@field grid_scale number
---@field objects table<sia.entity, ae.welt.vec2?>
---@field [number] table<number, sia.entity?>
---@overload fun(config?: ae.welt.space.config): ae.welt.space
components.space = entity.component(function(config)
    return {
        grid_scale = config.grid_scale or 1,
        objects = {}
    }
end)

---@param e sia.entity
---@return boolean
function components.space:has_object(e)
    return self.objects[e] ~= nil
end

---@param x integer
---@param y integer
---@return sia.entity?
function components.space:get_object_in_grid(x, y)
    local column = self[x]
    if column == nil then
        return nil
    end
    local grid = column[y]
    if grid == nil then
        return nil
    end
    return grid[1]
end

local empty_iter = function()
    return nil
end

---@param x integer
---@param y integer
---@return fun(table: sia.entity[], i?: integer): integer, sia.entity
---@return sia.entity[]?
---@return number?
function components.space:iter_objects_in_grid(x, y)
    local column = self[x]
    if column == nil then
        return empty_iter, nil, nil
    end
    local grid = column[y]
    if grid == nil then
        return empty_iter, nil, nil
    end
    return ipairs(grid)
end

---@param e sia.entity
---@return integer
---@return integer
function components.space:get_object_grid_point(e)
    local grid_pos = self.objects[e]
    if grid_pos == nil then
        error("object not found in space")
    end
    return grid_pos.x, grid_pos.y
end

---@class ae.welt.in_space: sia.component
---@field entity sia.entity
---@overload fun(world: ae.welt.space): ae.welt.in_space
components.in_space = entity.component(function(entity)
    return {
        entity = entity
    }
end)

---@class ae.welt.obstacle: sia.component
---@overload fun(): ae.welt.obstacle
components.obstacle = entity.component(function()
    return {}
end)

return components;