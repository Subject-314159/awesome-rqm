local const = require("lib.const")
local util = require("lib.util")
local stech = require("lib.state.tech")
local translate = require("lib.state.translate")

local state = {}

--------------------------------------------------------------------------------
--- Player settings (as per GUI)
--------------------------------------------------------------------------------

local get_global_player = function(player_index)
    -- init_settings_player(player_index)
    return storage.state.players[player_index]
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
    return storage.state.forces[force_index]
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
--- Technology state // pass-through
--------------------------------------------------------------------------------

-- state.get_technology = function(force_index, technology_name)
--     return stech.get_technology(force_index, technology_name)
-- end

-- TBD if we need to make this public
-- state.get_unresearched_technologies_ordered = function(force_index)
--     return stech.get_unresearched_technologies_ordered(force_index)
-- end

state.get_filtered_technologies_player = function(player_index)
    -- Static filter array
    local filter = {
        allowed_sciences = {}, -- Populate dynamically
        hide_tech = {}, -- Populate dynamically
        show_tech = state.get_player_setting(player_index, "show_tech_filter_category",
            const.default_settings.player.show_tech.selected),
        search_text = state.get_player_setting(player_index, "search_text")
    }

    -- Populate show sciences from sciences
    local sci = util.get_all_sciences()
    for _, s in pairs(sci) do
        -- filter.sciences[s] = state.get_player_setting(player_index, "allowed_" .. s, false)
        if state.get_player_setting(player_index, "allowed_" .. s, false) then
            table.insert(filter.allowed_sciences, s)
        end
    end

    -- Populate hide tech from const
    for k, v in pairs(const.default_settings.player.hide_tech) do
        filter.hide_tech[k] = state.get_player_setting(player_index, k, v)
    end

    -- Get the technologies
    return stech.get_filtered_technologies_player(player_index, filter)
end

state.get_tech_meta = function(force_index)
    return stech.get_tech_meta(force_index)
end

state.register_queued = function(force_index, tech_name)
    stech.register_queued(force_index, tech_name)
end
state.deregister_queued = function(force_index, tech_name)
    stech.deregister_queued(force_index, tech_name)
end

-- state.update_technology = function(force_index, technology_name)
--     stech.update_technology(force_index, technology_name)
-- end

-- state.update_technology_queued = function(force_index, technology_name)
--     stech.update_technology_queued(force_index, technology_name)
-- end

-- state.update_pending_technology = function(force_index)
--     stech.update_pending_technology(force_index)
-- end
--------------------------------------------------------------------------------
--- Environment settings
--------------------------------------------------------------------------------

state.get_environment_setting = function(setting_name)
    return storage.state.env[setting_name]
end
state.set_environment_setting = function(setting_name, value)
    storage.state.env[setting_name] = value
end

local set_default_environment_variables = function()

    -- Store array of available sciences
    local sci = {}
    local prop = {
        filter = "type",
        type = "lab"
    }
    local labs = prototypes.get_entity_filtered({prop})

    for _, l in pairs(labs) do
        for _, s in pairs(l.lab_inputs) do
            util.insert_unique(sci, s)
        end
    end
    state.set_environment_setting("available_sciences", sci)
end

--------------------------------------------------------------------------------
--- Control flags
--------------------------------------------------------------------------------

local set_update = function(f, s, t)
    if not f then
        return
    end
    storage.state.forces[f.index].tick_flags[s] = game.tick + (t or 2)
end

local get_update = function(f, s)
    if not f then
        return false
    end
    if not storage.state.forces then
        return false
    end
    if not storage.state.forces[f.index] then
        return false
    end

    if not storage.state.forces[f.index].tick_flags then
        return false
    end
    local tf = storage.state.forces[f.index].tick_flags[s]
    if not tf then
        return false
    end
    if tf <= game.tick then
        storage.state.forces[f.index].tick_flags[s] = nil
        return true
    end
    return false
end

state.request_technology_update = function(f, tech_name)
    stech.request_technology_update(f.index, tech_name)
end
state.tech_needs_update = function(f)
    return stech.technology_needs_update(f.index)
end

state.request_gui_update = function(f)
    set_update(f, "gui_needs_update")
end

state.gui_needs_update = function(f)
    return get_update(f, "gui_needs_update")
end

state.request_queue_sync = function(f)
    set_update(f, "queue_needs_update")
end

state.queue_needs_sync = function(f)
    return get_update(f, "queue_needs_update")
end

state.request_next_research = function(f)
    set_update(f, "needs_next_research")
end

state.research_needs_next = function(f)
    return get_update(f, "needs_next_research")
end

state.request_ingame_queue_cleanup = function(f)
    set_update(f, "queue_needs_cleanup")
end

state.ingame_queue_needs_cleanup = function(f)
    return get_update(f, "queue_needs_cleanup")
end

--------------------------------------------------------------------------------
--- Initializing
--------------------------------------------------------------------------------

local init_state = function()
    -- Init emtpy storage.state
    if not storage then
        storage = {}
    end
    if not storage.state then
        storage.state = {}
    end
    if not storage.state.forces then
        storage.state.forces = {}
    end
    if not storage.state.players then
        storage.state.players = {}
    end
    if not storage.state.env then
        storage.state.env = {}
    end
end

state.init_player = function(player_index)
    -- Init new array for player
    if not storage.state.players[player_index] then
        storage.state.players[player_index] = {}
    end
    translate.request(player_index)
end

state.init_force = function(force_index)
    -- Init new array for force
    if not storage.state.forces[force_index] then
        storage.state.forces[force_index] = {
            tick_flags = {}
        }
    end
    stech.init_force(f.index)
end

-- state.init_force_updates = function(force_index)
--     stech.init_force(force_index)
-- end

state.init = function()
    -- Init empty array
    init_state()

    -- Populate default environments variables
    set_default_environment_variables()

    --Init tech
    stech.init()

    -- Populate forces
    for _, f in pairs(game.forces) do
        state.init_force(f.index)
        stech.init_force(f.index)
    end

    -- Populate players
    for _, p in pairs(game.players) do
        state.init_player(p.index)
    end
end

state.init_updates = function()
    for _, f in pairs(game.forces) do
        state.init_force_updates(f.index)
    end
end

return state
