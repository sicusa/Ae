local entity = require("sia.entity")
local system = require("sia.system")
local lume = require("lume")
local vec2 = require("cpml.modules.vec2")

local components = require("ae.core.welt.components")

local floor = math.floor
local remove = lume.remove

-- transform

local position = components.position
local rotation = components.rotation
local scale = components.scale
local constraint = components.constraint
local constraint_library = components.constraint_library

local constraint_library_state = entity.component(function(config)
    return {
        position_handler = config.position_handler,
        rotation_handler = config.rotation_handler,
        scale_handler = config.scale_handler
    }
end)

local constraint_library_initialize_system = system {
    select = {constraint_library},
    trigger = {"add"},

    execute = function(world, sched, e)
        local lib = e[constraint_library]

        if world[constraint_library] == lib then
            print("error: constraint library already exists")
            world:remove(e)
            return
        end
        world[constraint_library] = lib

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
    select = {constraint_library},
    trigger = {"remove"},
    depend = {constraint_library_initialize_system},

    execute = function(world, sched, e)
        local lib = e[constraint_library]

        if world[constraint_library] ~= lib then
            return
        end
        world[constraint_library] = nil

        local state = e[constraint_library_state]
        local disp = world.dispatcher
        disp:unlisten(position.set, state.position_handler)
        disp:unlisten(rotation.set, state.rotation_handler)
        disp:unlisten(scale.set, state.scale_handler)
    end
}

local constraint_state = entity.component(function(config)
    return {
        target_remove_handler = config.target_remove_handler
    }
end)

local constraint_initialize_system = system {
    select = {constraint},
    trigger = {"add"},
    depend = {
        constraint_library_initialize_system,
        constraint_library_uninitialize_system
    },

    execute = function(world, sched, e)
        local lib = world[constraint_library]
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

        local position_offset = c.position_offset
        local rotation_offset = c.rotation_offset
        local scale_offset = c.scale_offset

        if position_offset == nil then
            world:modify(target, position.set, )
        else
            world:modify(target, position.set, vec2.add(value, offset))
        end

    end
}

local constraint_uninitialize_system = system {
    select = {constraint},
    trigger = {"remove"},
    depend = {constraint_initialize_system},

    execute = function(world, sched, e)
        local lib = world[constraint_library]
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

local transform_systems = system {
    name = "ae.welt.transform_systems",
    authors = {"Phlamcenth Sicusa <sicusa@gilatod.art>"},
    description = "Transform systems",
    version = {0, 0, 1},

    children = {
        constraint_library_initialize_system,
        constraint_library_uninitialize_system,
        constraint_initialize_system,
        constraint_uninitialize_system
    }
}

-- space

local in_space = components.in_space
local obstacle = components.obstacle

local function add_object_in_space_grid(space, obj, pos)
    local scale = space.grid_scale
    local column = space[floor(pos.x / scale)]
    if column == nil then
        column = {}
        space[pos.x] = column
    end
    local row = column[floor(pos.y / scale)]
    if row == nil then
        row = {obj}
        space[pos.y] = row
    else
        row[#row+1] = obj
    end
end

local function remove_object_in_space_grid(space, obj, pos)
    local scale = space.grid_scale
    local column = space[floor(pos.x / scale)]
    if column == nil then
        return
    end
    local row = column[floor(pos.y / scale)]
    if row == nil then
        return
    end
    return remove(row, obj)
end

local in_space_state = entity.component(function(last_position)
    return {last_position}
end)

local in_space_object_initialize_system = system {
    select = {in_space, position},
    trigger = {"add"},

    execute = function(world, sched, e)
        local p = e[position]
        local s = e[in_space].space

        for obj in s:get_object_in_grid(p) do
            if obj[obstacle] ~= nil then
                print("error: object to be placed in the space has been occupied by an obstacle")
                world:remove(e)
                return
            end
        end

        add_object_in_space_grid(s, e, p)
        e:add_state(in_space_state(p))
    end
}

local in_space_object_move_system = system {
    select = {in_space, position},
    trigger = {position.set},

    execute = function(world, sched, e)
        local p = e[position]
        local s = e[in_space].space
    end
}

local in_space_object_uninitialize_system = system {
    select = {in_space, position},
    trigger = {"remove"},
    depend = {in_space_object_initialize_system},

    execute = function(world, sched, e)
        local state = e[in_space_state]
        if state == nil then return end

        local s = e[in_space].space
        local p = state[1]

        if not remove_object_in_space_grid(s, e, p) then
            print("internal error: object not found")
        end
    end
}

local space_systems = system {
    name = "ae.welt.space_systems",
    authors = {"Phlamcenth Sicusa <sicusa@gilatod.art>"},
    description = "Space systems",
    version = {0, 0, 1},

    depend = {transform_systems},
    children = {
        in_space_object_initialize_system,
        in_space_object_uninitialize_system
    }
}

return system {
    name = "ae.welt.systems",
    authors = {"Phlamcenth Sicusa <sicusa@gilatod.art>"},
    description = "Welt systems",
    version = {0, 0, 1},

    children = {
        transform_systems,
        space_systems
    }
}