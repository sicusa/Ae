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
    select = {constraint},
    trigger = {"add"},
    depend = {
        constraint_library_initialize_system,
        constraint_library_uninitialize_system
    },

    execute = function(world, sched, e)
        local lib = world[constraint_library]
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

local constraint_update_system = system {
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

local constraint_uninitialize_system = system {
    select = {constraint},
    trigger = {"remove"},
    depend = {constraint_initialize_system},

    execute = function(world, sched, e)
        local lib = world[constraint_library]
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
    children = {
        constraint_library_initialize_system,
        constraint_library_uninitialize_system,
        constraint_initialize_system,
        constraint_update_system,
        constraint_uninitialize_system
    }
}

-- space

local space = components.space
local in_space = components.in_space
local obstacle = components.obstacle

local function add_object_in_space_grid(space, obj, grid_x, grid_y)
    local column = space[grid_x]
    if column == nil then
        column = {}
        space[grid_x] = column
    end
    local grid = column[grid_y]
    if grid == nil then
        grid = {obj}
        column[grid_y] = grid
    else
        grid[#grid+1] = obj
    end
end

local function remove_object_in_space_grid(space, obj, grid_x, grid_y)
    local column = space[grid_x]
    if column == nil then
        return
    end
    local grid = column[grid_y]
    if grid == nil then
        return
    end
    if not remove(grid, obj) then
        return
    end

    if #grid == 0 then
        column[grid_y] = nil
        if next(column) == nil then
            space[grid_x] = nil
        end
    end
    return true
end

local function check_grid_occupied(space, grid_x, grid_y)
    for _, obj in space:iter_objects_in_grid(grid_x, grid_y) do
        if obj[obstacle] ~= nil then
            return true
        end
    end
    return false
end

local in_space_state = entity.component(function(last_position, last_grid)
    return {
        last_position = last_position,
        last_grid = last_grid
    }
end)

local in_space_object_place_system = system {
    select = {in_space, position},
    trigger = {"add", position.set},

    execute = function(world, sched, e)
        local p = e[position]
        local s = e[in_space].entity[space]
        local state = e[in_space_state]

        local scale = s.grid_scale
        local grid_x = floor(p.x / scale)
        local grid_y = floor(p.y / scale)

        if state == nil then
            if s == nil then
                print("error: invalid space")
                world:remove(e)
                return
            elseif check_grid_occupied(s, grid_x, grid_y) then
                print("error: cannot create object in a space grid occupied by obstacle")
                world:remove(e)
                return
            end
            world:add(s)

            local grid_pos = position(grid_x, grid_y)
            s.objects[e] = grid_pos
            e:add_state(in_space_state(position(p.x, p.y), grid_pos))
        else
            local last_pos = state.last_position
            local last_grid = state.last_grid

            if last_grid.x == grid_x and last_grid.y == grid_y then
                last_pos.x = p.x
                last_pos.y = p.y
                return
            elseif check_grid_occupied(s, grid_x, grid_y) then
                world:modify(e, position.set, last_pos)
                return
            end

            last_pos.x = p.x
            last_pos.y = p.y

            remove_object_in_space_grid(s, e, last_grid.x, last_grid.y)
            last_grid.x = grid_x
            last_grid.y = grid_y
        end

        add_object_in_space_grid(s, e, grid_x, grid_y)
    end
}

local in_space_object_uninitialize_system = system {
    select = {in_space, position},
    trigger = {"remove"},
    depend = {in_space_object_place_system},

    execute = function(world, sched, e)
        local state = e[in_space_state]
        if state == nil then return end

        local s = e[in_space].entity[space]
        local p = state.last_position

        s.objects[e] = nil
        if not remove_object_in_space_grid(s, e, p.x, p.y) then
            print("internal error: failed to remove object from space grid")
        end
    end
}

local space_systems = system {
    name = "ae.welt.space_systems",
    depend = {transform_systems},
    children = {
        in_space_object_place_system,
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