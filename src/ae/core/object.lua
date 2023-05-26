local entity = require("sia.entity")
local system = require("sia.system")

local singleton = require("ae.utils.singleton")

---@class ae.object
local object = {}

-- components

---@class ae.object.name: sia.component
---@field value string
---@field set sia.command (value: string)
---@overload fun(value: string): ae.object.name
object.name = entity.component(function(value)
    return {
        value = value
    }
end)
:on("set", function(self, value)
    self.value = value
end)

---@class ae.object.name_library: sia.component
---@field [string] table<sia.entity, true?>
---@field [sia.entity] string
---@overload fun(value: string): ae.object.name_library
object.name_library = entity.component(function()
    return {}
end)

---@alias ae.object.monitor_event fun(world: sia.world, sched: sia.scheduler, entity: sia.entity)

---@class ae.object.monitor.props
---@field target? sia.entity
---@field add? ae.object.monitor_event
---@field remove? ae.object.monitor_event
---@field [sia.command] ae.object.monitor_event

---@class ae.object.monitor: sia.component
---@field target? sia.entity
---@field add? ae.object.monitor_event
---@field remove? ae.object.monitor_event
---@field tick? ae.object.monitor_event
---@field [sia.command] ae.object.monitor_event
---@overload fun(props: ae.object.monitor.props): ae.object.monitor
object.monitor = entity.component(function(props)
    local data = {}
    for k, v in pairs(props) do
        data[k] = v
    end
    return data
end)

---@class ae.object.monitor_library: sia.component
---@field tick_callbacks {[0]: ae.object.monitor, [1]: sia.entity}[]
---@field [sia.entity] ae.object.monitor[]?
---@overload fun(): ae.object.monitor_library
object.monitor_library = entity.component(function()
    return {
        tick_callbacks = {}
    }
end)

-- systems

local name = object.name
local name_library = object.name_library
local monitor = object.monitor
local monitor_library = object.monitor_library

local name_record_system = system {
    name = "ae.object.name_record_system",
    select = {name},
    trigger = {"add", name.set},

    before_execute = function(world, sched)
        return singleton.acquire(world, name_library)
    end,

    execute = function(world, sched, e, lib)
        print(lib)
        local name_value = e[name].value
        local prev_name = lib[e]

        if prev_name ~= nil then
            local prev_slot = lib[prev_name]
            if prev_slot == nil then
                print("error: corrupted previous name "..prev_name)
            else
                prev_slot[e] = nil
            end
        end

        local slot = lib[name_value]
        if slot == nil then
            slot = {}
            lib[name_value] = slot
        end

        slot[e] = true
        lib[e] = name_value
    end
}

local name_unrecord_system = system {
    name = "ae.object.name_unrecord_system",
    select = {name},
    trigger = {"remove"},
    depend = {name_record_system},

    before_execute = function(world, sched)
        return singleton.acquire(world, name_library)
    end,

    execute = function(worl, sched, e, lib)
        local curr_name = lib[e]
        if curr_name == nil then
            print("error: corrupted name library")
            return
        end

        lib[e] = nil
        lib[curr_name][e] = nil
    end
}

local monitor_register_system = system {
    name = "ae.object.monitor_register_system",
    select = {monitor},
    trigger = {"add"},

    before_execute = function(world, sched)
        return singleton.acquire(world, monitor_library)
    end,

    execute = function(world, sched, e, lib)
        local m = e[monitor]
        local target = m.target

        if target ~= nil then
            world:add(target)
        else
            target = e
        end

        local monitors = lib[target]

        if monitors == nil then
            monitors = {}
            lib[target] = monitors

            monitors.__listener = function(command, e)
                for i = 1, #monitors do
                    local callback = monitors[i][command]
                    if callback then callback(world, sched, e) end
                end
            end
            world.dispatcher:listen_on(target, monitors.__listener)
        end

        local i = #monitors+1
        monitors[i] = m
        monitors[m] = i

        local tick = m.tick
        if tick ~= nil then
            local tick_callbacks = lib.tick_callbacks
            local tick_callback_i = #tick_callbacks+1
            tick_callbacks[tick_callback_i] = {tick, target}
            tick_callbacks[m] = tick_callback_i
        end
    end
}

local monitor_unregister_system = system {
    name = "ae.object.monitor_unregister_system",
    select = {monitor},
    trigger = {"remove"},
    depend = {monitor_register_system},

    before_execute = function(world, sched)
        return singleton.acquire(world, monitor_library)
    end,

    execute = function(world, sched, e, lib)
        local m = e[monitor]
        local target = m.target or e
        local monitors = lib[target]

        if monitors == nil then
            return
        end

        local i = monitors[m]
        if i == nil then
            print("error: corrupted monitors")
            return
        end

        local last_i = #monitors
        monitors[m] = nil
        monitors[i] = monitors[last_i]
        monitors[last_i] = nil

        if m.tick ~= nil then
            local tick_callbacks = lib.tick_callbacks
            local tick_callback_i = tick_callbacks[m]
            local last_tick_callback_i = #tick_callbacks
            tick_callbacks[m] = nil
            tick_callbacks[tick_callback_i] = tick_callbacks[last_tick_callback_i]
            tick_callbacks[last_tick_callback_i] = nil
        end

        if next(monitors) == nil then
            world.dispatcher:unlisten_on(target, monitors.__listener)
            lib[target] = nil
        end
    end
}

local monitor_tick_system = system {
    name = "ae.object.monitor_tick_system",
    select = {monitor_library},
    depend = {
        monitor_register_system,
        monitor_unregister_system
    },

    execute = function(world, sched, e)
        local lib = e[monitor_library]
        local tick_callbacks = lib.tick_callbacks

        for i = 1, #tick_callbacks do
            local entry = tick_callbacks[i]
            entry[1](world, sched, entry[2])
        end
    end
}

object.systems = system {
    name = "ae.object.systems",
    authors = {"Phlamcenth Sicusa <sicusa@gilatod.art>"},
    version = {0, 0, 1},
    children = {
        name_record_system,
        name_unrecord_system,
        monitor_register_system,
        monitor_unregister_system,
        monitor_tick_system
    }
}

return object