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

---@class ae.transform.constraint.props
---@field source sia.entity
---@field target sia.entity
---@field position_offset? ae.vec2
---@field rotation_offset? number
---@field scale_offset? number

---@class ae.transform.constraint: sia.component, ae.transform.constraint.props
---@field set_position_offset sia.command (v: vec2)
---@field set_rotation_offset sia.command (v: number)
---@field set_scale_offset sia.command (v: number)
---@overload fun(props: ae.transform.constraint.props): ae.transform.constraint
transform.constraint = entity.component(function(props)
    return {
        source = props.source,
        target = props.target,
        position_offset = props.position_offset,
        rotation_offset = props.rotation_offset,
        scale_offset = props.scale_offset
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

---@class ae.transform.constraint_library: sia.component
---@field [sia.entity] ae.transform.constraint[]
---@overload fun(): ae.transform.constraint_library
transform.constraint_library = entity.component(function()
    return {}
end)

-- systems

local position = transform.position
local rotation = transform.rotation
local scale = transform.scale
local constraint = transform.constraint
local constraint_library = transform.constraint_library

local constraint_library_state = entity.component(function(props)
    return {
        position_handler = props.position_handler,
        rotation_handler = props.rotation_handler,
        scale_handler = props.scale_handler
    }
end)

local constraint_library_initialize_system = system {
    name = "ae.transform.constraint_library_initialize_system",
    select = {constraint_library},
    trigger = {"add"},

    execute = function(world, sched, e)
        local lib = singleton.register(world, e, constraint_library, "constraint library")
        if lib == nil then return end

        local state = constraint_library_state {
            position_handler = function(_, source, value)
                local constraints = lib[source]
                if constraints == nil then
                    return
                end
                for i = 1, #constraints do
                    local c = constraints[i]
                    local offset = c.position_offset
                    if offset == nil then
                        world:modify(c.target, position.set, value)
                    else
                        world:modify(c.target, position.set, vec2.add(value, offset))
                    end
                end
            end,
            rotation_handler = function(_, source, value)
                local constraints = lib[source]
                if constraints == nil then
                    return
                end
                for i = 1, #constraints do
                    local c = constraints[i]
                    local offset = c.rotation_offset
                    if offset == nil then
                        world:modify(c.target, rotation.set, value)
                    else
                        world:modify(c.target, rotation.set, value + offset)
                    end
                end
            end,
            scale_handler = function(_, source, value)
                local constraints = lib[source]
                if constraints == nil then
                    return
                end
                for i = 1, #constraints do
                    local c = constraints[i]
                    local offset = c.scale_offset
                    if offset == nil then
                        world:modify(c.target, scale.set, value)
                    else
                        world:modify(c.target, scale.set, value * offset)
                    end
                end
            end
        }
        e:add_state(state)

        local disp = world.dispatcher
        disp:listen(position.set, state.position_handler)
        disp:listen(rotation.set, state.rotation_handler)
        disp:listen(scale.set, state.scale_handler)
    end
}

local constraint_library_uninitialize_system = system {
    name = "ae.transform.constraint_library_uninitialize_system",
    select = {constraint_library},
    trigger = {"remove"},
    depend = {constraint_library_initialize_system},

    execute = function(world, sched, e)
        local lib = singleton.unregister(world, e, constraint_library)
        if lib == nil then return end

        local state = e[constraint_library_state]
        local disp = world.dispatcher
        disp:unlisten(position.set, state.position_handler)
        disp:unlisten(rotation.set, state.rotation_handler)
        disp:unlisten(scale.set, state.scale_handler)
    end
}

local constraint_state = entity.component(function(props)
    return {
        target_remove_handler = props.target_remove_handler
    }
end)

local function apply_constraint(world, c)
    local source = c.source
    local target = c.target

    local source_p = source[position]
    if source_p ~= nil then
        local position_offset = c.position_offset
        if position_offset == nil then
            world:modify(target, position.set, source_p)
        else
            world:modify(target, position.set, vec2.add(source_p, position_offset))
        end
    end

    local source_r = source[rotation]
    if source_r ~= nil then
        local rotation_offset = c.rotation_offset
        if rotation_offset == nil then
            world:modify(target, rotation.set, source_r)
        else
            world:modify(target, rotation.set, source_r + rotation_offset)
        end
    end

    local source_s = source[scale]
    if source_s ~= nil then
        local scale_offset = c.scale_offset
        if scale_offset == nil then
            world:modify(target, scale.set, source_s)
        else
            world:modify(target, scale.set, source_s * scale_offset)
        end
    end
end

local constraint_initialize_system = system {
    name = "ae.transform.constraint_initialize_system",
    select = {constraint},
    trigger = {"add"},
    depend = {
        constraint_library_initialize_system,
        constraint_library_uninitialize_system
    },

    execute = function(world, sched, e)
        local lib = singleton.require(world, constraint_library, "constraint library")
        if lib == nil then return end

        local c = e[constraint]
        c._entity = e

        local source = c.source
        local target = c.target

        world:add(source)
        world:add(target)

        local constraints = lib[source]

        if constraints == nil then
            constraints = {}
            lib[source] = constraints

            local source_remove_handler = function(command)
                if command ~= "remove" then
                    return
                end
                lib[source] = nil
                for i = 1, #constraints do
                    world:remove(constraints[i]._entity)
                end
                return true
            end

            world.dispatcher:listen_on(source, source_remove_handler)
            constraints.source_remove_handler = source_remove_handler
        end

        local state = constraint_state {
            target_remove_handler = function(command)
                if command ~= "remove" then
                    return
                end
                world:remove(e)
                return true
            end
        }

        e:add_state(state)
        world.dispatcher:listen_on(target, state.target_remove_handler)

        constraints[#constraints + 1] = c
        apply_constraint(world, c)
    end
}

local constraint_uninitialize_system = system {
    name = "ae.transform.constraint_uninitialize_system",
    select = {constraint},
    trigger = {"remove"},
    depend = {constraint_initialize_system},

    execute = function(world, sched, e)
        local lib = singleton.require(world, constraint_library, "constraint library")
        if lib == nil then return end

        local c = e[constraint]
        local source = c.source
        local target = c.target

        local constraints = lib[source]
        if constraints == nil then return end

        if world:contains(target) then
            local state = e[constraint_state]
            world.dispatcher:unlisten_on(target, state.target_remove_handler)
        end

        remove(constraints, c)
        if #constraints == 0 then
            world.dispatcher:unlisten_on(source, constraints.source_remove_handler)
            lib[source] = nil
        end
    end
}

local constraint_update_system = system {
    name = "ae.transform.constraint_update_system",
    select = {constraint},
    trigger = {
        constraint.set_position_offset,
        constraint.set_rotation_offset,
        constraint.set_scale_offset
    },
    depend = {constraint_initialize_system},

    execute = function(world, sched, e)
        local c = e[constraint]
        apply_constraint(world, c)
    end
}

transform.systems = system {
    name = "ae.transform.systems",
    authors = {"Phlamcenth Sicusa <sicusa@gilatod.art>"},
    version = {0, 0, 1},
    children = {
        constraint_library_initialize_system,
        constraint_library_uninitialize_system,
        constraint_initialize_system,
        constraint_uninitialize_system,
        constraint_update_system
    }
}

return transform