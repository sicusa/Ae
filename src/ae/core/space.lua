local lume = require("lume")

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

---@class ae.space.object_data
---@field grid ae.vec2
---@field position ae.vec2

---@class ae.space.map: sia.component
---@field grid_scale number
---@field objects table<sia.entity, ae.space.object_data?>
---@field [number] table<number, sia.entity?>
---@overload fun(props?: ae.space.map.props): ae.space.map
space.map = entity.component(function(props)
    return {
        grid_scale = props.grid_scale or 1,
        objects = {}
    }
end)

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

---@class ae.space.in_map: sia.component
---@field [number] sia.entity
---@overload fun(...: sia.entity): ae.space.in_map
space.in_map = entity.component(function(...)
    return {...}
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

local function update_object_in_map(world, map_entity, e, p)
    local m = map_entity[map]
    if m == nil then
        print("error: invalid map")
        return
    end

    local data = m.objects[e]
    local scale = m.grid_scale
    local grid_x = floor(p.x / scale)
    local grid_y = floor(p.y / scale)

    if data == nil then
        if check_grid_occupied(m, grid_x, grid_y) then
            print("error: cannot create object in a map grid occupied by obstacle")
            return
        end
        world:add(map_entity)
        m.objects[e] = {
            grid = position(grid_x, grid_y),
            position = position(p.x, p.y)
        }
    else
        local last_pos = data.position
        local last_grid = data.grid

        if last_grid.x == grid_x and last_grid.y == grid_y then
            last_pos.x = p.x
            last_pos.y = p.y
            return
        elseif check_grid_occupied(m, grid_x, grid_y) then
            world:modify(e, position.set, last_pos)
            return
        end

        last_pos.x = p.x
        last_pos.y = p.y

        remove_object_in_map_grid(m, e, last_grid.x, last_grid.y)
        last_grid.x = grid_x
        last_grid.y = grid_y
    end

    add_object_in_map_grid(m, e, grid_x, grid_y)
end

local function remove_object_in_map(map_entity, e)
    local m = map_entity[map]
    if m == nil then
        return
    end

    local objects = m.objects
    local data = objects[e]
    if data == nil then
        return
    end

    local grid = data.grid
    if not remove_object_in_map_grid(m, e, grid.x, grid.y) then
        print("internal error: failed to remove object from map grid")
    end

    objects[e] = nil
end

local in_map_object_place_system = system {
    name = "ae.space.in_map_object_place_system",
    select = {in_map, position},
    trigger = {"add", position.set},

    execute = function(world, sched, e)
        local p = e[position]
        local maps = e[in_map]

        for i = 1, #maps do
            update_object_in_map(world, maps[i], e, p)
        end
    end
}

local in_map_object_uninitialize_system = system {
    name = "ae.space.in_map_object_uninitialize_system",
    select = {in_map, position},
    trigger = {"remove"},
    depend = {in_map_object_place_system},

    execute = function(world, sched, e)
        local maps = e[in_map]
        for i = 1, #maps do
            remove_object_in_map(maps[i], e)
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