local const = require("lib.const")
local util = require("lib.util")
-- local stech = require("lib.state.tech")
local translate = require("model.state.translate")

local state = {}

--------------------------------------------------------------------------------
--- Player settings (as per GUI)
--------------------------------------------------------------------------------

local get_global_player = function(player_index)
    -- init_settings_player(player_index)
    return storage.players[player_index].state
end

state.store_translation = function(player_index, id, translated_string, localised_string)
    translate.store(player_index, id, translated_string, localised_string)
end
state.get_translation = function(player_index, type, name, field)
    return translate.get(player_index, type, name, field)
end

state.get_player_setting = function(player_index, setting_name, default_setting)
    local gp = get_global_player(player_index)
    if gp[setting_name] ~= nil then
        return gp[setting_name]
    else
        return default_setting
    end
end

state.set_player_setting = function(player_index, setting_name, setting_value)
    local gp = get_global_player(player_index)
    gp[setting_name] = setting_value
end

state.clear_player_setting = function(player_index, setting_name)
    local gp = get_global_player(player_index)
    gp[setting_name] = nil
end

state.toggle_player_setting = function(player_index, setting_name)
    -- Get current setting or false
    local s = state.get_player_setting(player_index, setting_name) or false
    if type(s) ~= "boolean" then
        s = true
    end
    state.set_player_setting(player_index, setting_name, not s)
end

--------------------------------------------------------------------------------
--- Force settings (as per GUI)
--------------------------------------------------------------------------------

local get_global_force = function(force_index)
    -- init_settings_force(force_index)
    return storage.forces[force_index].state
end

state.get_force_setting = function(force_index, setting_name, default_setting)
    local gp = get_global_force(force_index)
    if gp[setting_name] ~= nil then
        return gp[setting_name]
    else
        return default_setting
    end
end

state.set_force_setting = function(force_index, setting_name, setting_value)
    local gp = get_global_force(force_index)
    gp[setting_name] = setting_value
end

state.clear_force_setting = function(force_index, setting_name)
    local gp = get_global_force(force_index)
    gp[setting_name] = nil
end

state.toggle_force_setting = function(force_index, setting_name)
    -- Get current setting or false
    local s = state.get_force_setting(force_index, setting_name) or false
    if type(s) ~= "boolean" then
        s = true
    end
    state.set_force_setting(force_index, setting_name, not s)
end

--------------------------------------------------------------------------------
--- Control flags
--------------------------------------------------------------------------------

local set_update = function(f, s, t)
    if not f then
        return
    end
    storage.forces[f.index].state.tick_flags[s] = game.tick + (t or 1)
end

local get_update = function(f, s)
    if not f then
        return false
    end
    if not storage.forces[f.index].state then
        return false
    end

    if not storage.forces[f.index].state.tick_flags then
        return false
    end
    local tf = storage.forces[f.index].state.tick_flags[s]
    if not tf then
        return false
    end
    if tf <= game.tick then
        storage.forces[f.index].state.tick_flags[s] = nil
        return true
    end
    return false
end

state.request_gui_update = function(f)
    set_update(f, "gui_needs_update")
end
state.gui_needs_update = function(f)
    return get_update(f, "gui_needs_update")
end

state.request_next_research = function(f)
    set_update(f, "needs_next_research")
end
state.research_needs_next = function(f)
    return get_update(f, "needs_next_research")
end

state.request_queue_sync = function(f)
    set_update(f, "queue_needs_update")
end
state.queue_needs_sync = function(f)
    return get_update(f, "queue_needs_update")
end

state.request_ingame_queue_cleanup = function(f)
    set_update(f, "queue_needs_cleanup", 10 * 60)
end
state.ingame_queue_needs_cleanup = function(f)
    return get_update(f, "queue_needs_cleanup")
end

--------------------------------------------------------------------------------
--- Initializing
--------------------------------------------------------------------------------

state.init_player = function(player_index)
    -- Init new array for player
    if not storage.players[player_index].state then
        storage.players[player_index].state = {}
    end
    translate.request(player_index)
end

state.init_force = function(force_index)
    -- Init new array for force
    if not storage.forces[force_index].state then
        storage.forces[force_index].state = {
            tick_flags = {}
        }
    end
end

return state
