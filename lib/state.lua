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

-- local request_translations = function(player_index)
--     local p = game.get_player(player_index)
--     if not p then
--         game.print("[RQM] ERROR: Requested translation but no player found for player_index " .. player_index ..
--                        ", please open a bug report on the mod portal")
--         return
--     end
--     local f = p.force
--     local gp = get_global_player(player_index)
--     gp.translations = {}
--     local gpt = gp.translations
--     gpt.requested = {}
--     local gptr = gpt.requested

--     local prop = {}

--     local att = {"entity", "item", "fluid", "equipment", "recipe", "technology"} -- Needed "quality", "tile"?
--     for _, a in pairs(att) do
--         for _, t in pairs(prototypes[a]) do
--             -- Store the request ID in the requested array and add the type/field identifiers so we can map it easier when we get the translation back 
--             local propn = {
--                 type = a,
--                 name = t.name,
--                 localised_name = t.localised_name,
--                 field = "localised_name"
--             }
--             local idn = p.request_translation(t.localised_name)
--             if idn then
--                 gptr[idn] = propn
--             end

--             local propd = {
--                 type = a,
--                 name = t.name,
--                 localised_description = t.localised_description,
--                 field = "localised_description"
--             }
--             local idd = p.request_translation(t.localised_description)
--             if idd then
--                 gptr[idd] = propd
--             end
--         end
--     end
-- end

-- state.store_translation = function(player_index, id, translated_string, localised_string)
--     -- Get the player storage or early exit if we have no translations array
--     -- init_settings_player(player_index)
--     local gpt = storage.state.players[player_index].translations
--     if not gpt then
--         return
--     end

--     -- Early exit if this is an unrequested translation (eg. from other mods)
--     local gptr = gpt.requested[id]
--     if not gptr or gptr == nil then
--         return
--     end

--     if gpt[gptr.type] == nil or next(gpt[gptr.type]) == nil then
--         gpt[gptr.type] = {}
--     end
--     local gptt = gpt[gptr.type]
--     if gptt[gptr.name] == nil or next(gptt[gptr.name]) == nil then
--         gptt[gptr.name] = {}
--     end

--     -- Store the translation
--     gptt[gptr.name][gptr.field] = translated_string

--     -- Remove the requested ID from the array
--     gpt.requested[id] = nil
-- end

-- state.get_translation = function(player_index, type, name, field)
--     local gp = get_global_player(player_index)
--     if not gp then
--         return
--     end
--     local gpt = gp.translations
--     if not gpt then
--         game.print("[RQM] ERROR: Unable to search locale, please wait until translations are complete and try again")
--         request_translations(player_index)
--         return
--     end
--     local gptt = gpt[type]
--     if not gptt then
--         return
--     end
--     local gpttn = gptt[name]
--     if not gpttn then
--         return
--     else
--         return gpttn[field]
--     end
-- end

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

state.get_technology = function(force_index, technology_name)
    return stech.get_technology(force_index, technology_name)
end

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

state.update_technology = function(force_index, technology_name)
    stech.update_technology(force_index, technology_name)
end

state.update_technology_queued = function(force_index, technology_name)
    stech.update_technology_queued(force_index, technology_name)
end

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

    -- Init technology here because it needs to be done before queue.init
    stech.init_env()
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

    -- Do not init state-tech.force because it needs to be done after queue.init
end

state.init_force_updates = function(force_index)
    stech.init_force(force_index)
end

state.init = function()
    -- Init empty array
    init_state()

    -- Populate default environments variables
    set_default_environment_variables()

    -- Populate forces
    for _, f in pairs(game.forces) do
        state.init_force(f.index)
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
