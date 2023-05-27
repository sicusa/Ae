local ffi = require("ffi")
local lume = require("lume")
local vec2 = require("cpml.modules.vec2")

local entity = require("sia.entity")
local system = require("sia.system")
local group = require("sia.group")
local ffic = require("sia.ffic")

local singleton = require("ae.utils.singleton")

local floor = math.floor
local remove = lume.remove

---@alias ae.vec2 {x: number, y: number}
---@alias ae.vec3 {x: number, y: number, z: number}

---@class ae.space
local space = {}

-- components

ffi.cdef[[
    struct ae_space_position {
        float x, y;
    };
    struct ae_space_rotation {
        float value;
    };
    struct ae_space_scale {
        float x, y;
    };
]]

---@class ae.space.position: ffi.ctype*
---@field x number
---@field y number
---@field set sia.command (v: vec2)
---@overload fun(x: number, y: number): ae.space.position
space.position = ffic.struct("ae_space_position", {
    set = function(self, v)
        self.x = v.x
        self.y = v.y
    end
})

---@class ae.space.rotation: ffi.ctype*
---@field value number
---@field set sia.command (v: number)
---@overload fun(v: number): ae.space.rotation
space.rotation = ffic.struct("ae_space_rotation", {
    set = function(self, v)
        self.value = v
    end
})

---@class ae.space.scale: ffi.ctype*
---@field x number
---@field y number
---@field set sia.command (v: vec2)
---@overload fun(x: number, y: number): ae.space.scale
space.scale = ffic.struct("ae_space_scale", {
    set = function(self, v)
        self.x = v.x
        self.y = v.y
    end
})

---@class ae.space.node: sia.component
---@field parent? sia.entity
---@field applied_parent? sia.entity
---@field children sia.group
---@field dirty_children_nodes ae.space.node[]
---@field local_transform love.Transform
---@field world_transform love.Transform
---@field status nil | 'dirty' | 'modified'
---@field is_identity boolean
---@field set_parent sia.command (parent: sia.entity)
---@overload fun(parent?: sia.entity)
space.node = entity.component(function(parent)
    local instance = {
        parent = parent,
        children = group(),
        dirty_children_nodes = {},
        local_transform = love.math.newTransform(),
        world_transform = love.math.newTransform(),
        is_identity = true
    }
    return instance
end)
:on("set_parent", function(self, parent)
    self.parent = parent
end)

---@class ae.space.node_data
---@field dirty boolean

---@class ae.space.node_library: sia.component
---@field roots sia.group
---@field dirty_root_nodes ae.space.node[]
---@overload fun(): ae.space.node_library
space.node_library = entity.component(function()
    return {
        roots = group(),
        dirty_root_nodes = {}
    }
end)

---@class ae.space.map_object_data
---@field grid ae.vec2
---@field position ae.vec2

---@class ae.space.map.props
---@field grid_scale? number

---@class ae.space.map: sia.component
---@field grid_scale number
---@field objects table<sia.entity, ae.space.map_object_data?>
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

local position = space.position
local rotation = space.rotation
local scale = space.scale
local node = space.node
local node_library = space.node_library
local map = space.map
local in_map = space.in_map
local obstacle = space.obstacle

local function clear_dirty_children_nodes(node)
    local nodes = node.dirty_children_nodes
    for i = 1, #nodes do
        local child_node = nodes[i]
        child_node.status = nil
        clear_dirty_children_nodes(child_node)
        nodes[i] = nil
    end
end

local function tag_modified(lib, n)
    if n.status == 'modified' then
        return
    end
    n.status = 'modified';
    clear_dirty_children_nodes(n)

    local p_e = n.applied_parent
    while p_e ~= nil do
        local p = p_e[node]
        local status = p.status
        if status == 'dirty' then
            return
        end
        p.status = 'dirty'

        local dirty_children_nodes = p.dirty_children_nodes
        dirty_children_nodes[#dirty_children_nodes+1] = n

        n = p
        p_e = n.applied_parent
    end

    local dirty_root_nodes = lib.dirty_root_nodes
    dirty_root_nodes[#dirty_root_nodes+1] = n
end

local node_hierarchy_update_system = system {
    name = "ae.space.node_hierarchy_update_system",
    select = {node},
    trigger = {"add", node.set_parent},

    before_execute = function(world, sched)
        return singleton.acquire(world, node_library)
    end,
    
    execute = function(world, sched, e, lib)
        local n = e[node]
        local parent = n.parent
        local applied_parent = n.applied_parent

        if parent == applied_parent then
            return
        elseif applied_parent ~= nil then
            applied_parent.children:remove(e)
        end

        local roots = lib.roots
        if parent == nil then
            roots:add(e)
        else
            roots:remove(e)
            world:add(parent)
            parent[node].children:add(e)
        end

        n.applied_parent = parent
        tag_modified(lib, n)
    end
}

local node_local_transforms_update_system = system {
    name = "ae.space.node_local_transforms_update_system",
    select = {node},
    trigger = {"add", position.set, rotation.set, scale.set},
    depend = {node_hierarchy_update_system},

    before_execute = function(world, sched)
        return singleton.acquire(world, node_library)
    end,

    execute = function(world, sched, e, lib)
        local n = e[node]
        local local_trans = n.local_transform

        local px, py = 0, 0
        local r = 0
        local sx, sy = 1, 1

        local c_p = e[position]
        if c_p ~= nil then
            px = c_p.x
            py = c_p.y
        end

        local c_r = e[rotation]
        if c_r ~= nil then
            r = c_r.value
        end

        local c_s = e[scale]
        if c_s ~= nil then
            sx = c_s.x
            sy = c_s.y
        end

        n.is_identity = false
        local_trans:setTransformation(px, py, r, sx, sy)
        tag_modified(lib, n)
    end
}

local function update_modified_node(n, parent_world_trans)
    local local_trans = n.local_transform
    local world_trans = n.world_transform

    world_trans:setMatrix(parent_world_trans:getMatrix())
        :apply(local_trans)

    local children = n.children
    for i = 1, #children do
        update_modified_node(children[i][node], world_trans)
    end
end

local function update_dirty_node(node, parent_world_trans)
    if node.status == 'modified' then
        update_modified_node(node, parent_world_trans)
        return
    end

    local world_trans = node.world_transform
    local nodes = node.dirty_children_nodes

    for i = 1, #nodes do
        update_dirty_node(nodes[i], world_trans)
        nodes[i] = nil
    end
end

local DEFAULT_TRANSFORM = love.math.newTransform()

local node_world_transforms_update_system = system {
    name = "ae.space.node_world_transforms_update_system",
    select = {node_library},
    depend = {node_local_transforms_update_system},

    execute = function(world, sched, e)
        local lib = e[node_library]
        local nodes = lib.dirty_root_nodes

        for i = 1, #nodes do
            update_dirty_node(nodes[i], DEFAULT_TRANSFORM)
            nodes[i] = nil
        end
    end
}

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
    local grid_scale = m.grid_scale
    local grid_x = floor(p.x / grid_scale)
    local grid_y = floor(p.y / grid_scale)

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
    depend = {space.systems},
    children = {
        node_hierarchy_update_system,
        node_local_transforms_update_system,
        node_world_transforms_update_system,
        in_map_object_place_system,
        in_map_object_uninitialize_system
    }
}

return space