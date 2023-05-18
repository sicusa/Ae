local entity = require("sia.entity")
local system = require("sia.system")

local transform = require("ae.core.transform")
local position = transform.position

local floor = math.floor
local remove = lume.remove

---@class ae.space
local space = {}

-- components

---@class ae.space.map.props
---@field grid_scale? number

---@class ae.space.map: sia.component
---@field grid_scale number
---@field objects table<sia.entity, ae.vec2?>
---@field [number] table<number, sia.entity?>
---@overload fun(props?: ae.space.map.props): ae.space
space.map = entity.component(function(props)
    return {
        grid_scale = props.grid_scale or 1,
        objects = {}
    }
end)

---@param e sia.entity
---@return boolean
function space.map:has_object(e)
    return self.objects[e] ~= nil
end

---@param x integer
---@param y integer
---@return sia.entity?
function space.map:get_object_in_grid(x, y)
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
function space.map:iter_objects_in_grid(x, y)
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
function space.map:get_object_grid_point(e)
    local grid_pos = self.objects[e]
    if grid_pos == nil then
        error("object not found in space")
    end
    return grid_pos.x, grid_pos.y
end

---@class ae.space.in_map: sia.component
---@field entity sia.entity
---@overload fun(world: ae.space): ae.space.in_map
space.in_map = entity.component(function(entity)
    return {
        entity = entity
    }
end)

---@class ae.space.obstacle: sia.component
---@overload fun(): ae.space.obstacle
space.obstacle = entity.component(function()
    return {}
end)

-- systems

local map = space.map
local in_map = space.in_map
local obstacle = space.obstacle

local function add_object_in_map_grid(map, obj, grid_x, grid_y)
    local column = map[grid_x]
    if column == nil then
        column = {}
        map[grid_x] = column
    end
    local grid = column[grid_y]
    if grid == nil then
        grid = {obj}
        column[grid_y] = grid
    else
        grid[#grid+1] = obj
    end
end

local function remove_object_in_map_grid(map, obj, grid_x, grid_y)
    local column = map[grid_x]
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
            map[grid_x] = nil
        end
    end
    return true
end

local function check_grid_occupied(map, grid_x, grid_y)
    for _, obj in map:iter_objects_in_grid(grid_x, grid_y) do
        if obj[obstacle] ~= nil then
            return true
        end
    end
    return false
end

local in_map_state = entity.component(function(last_position, last_grid)
    return {
        last_position = last_position,
        last_grid = last_grid
    }
end)

local in_map_object_place_system = system {
    name = "ae.space.in_map_object_place_system",
    select = {in_map, position},
    trigger = {"add", position.set},

    execute = function(world, sched, e)
        local p = e[position]
        local s = e[in_map].entity[map]
        local state = e[in_map_state]

        local scale = s.grid_scale
        local grid_x = floor(p.x / scale)
        local grid_y = floor(p.y / scale)

        if state == nil then
            if s == nil then
                print("error: invalid map")
                world:remove(e)
                return
            elseif check_grid_occupied(s, grid_x, grid_y) then
                print("error: cannot create object in a map grid occupied by obstacle")
                world:remove(e)
                return
            end
            world:add(s)

            local grid_pos = position(grid_x, grid_y)
            s.objects[e] = grid_pos
            e:add_state(in_map_state(position(p.x, p.y), grid_pos))
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

            remove_object_in_map_grid(s, e, last_grid.x, last_grid.y)
            last_grid.x = grid_x
            last_grid.y = grid_y
        end

        add_object_in_map_grid(s, e, grid_x, grid_y)
    end
}

local in_map_object_uninitialize_system = system {
    name = "ae.space.in_map_object_uninitialize_system",
    select = {in_map, position},
    trigger = {"remove"},
    depend = {in_map_object_place_system},

    execute = function(world, sched, e)
        local state = e[in_map_state]
        if state == nil then return end

        local s = e[in_map].entity[map]
        local p = state.last_position

        s.objects[e] = nil
        if not remove_object_in_map_grid(s, e, p.x, p.y) then
            print("internal error: failed to remove object from map grid")
        end
    end
}

space.systems = system {
    name = "ae.space.systems",
    authors = {"Phlamcenth Sicusa <sicusa@gilatod.art>"},
    version = {0, 0, 1},
    depend = {transform.systems},
    children = {
        in_map_object_place_system,
        in_map_object_uninitialize_system
    }
}

return space