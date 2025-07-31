local state = {}

local util = require('util')

local init_settings = function()
    if not storage then
        storage = {}
    end
    if not storage.state then
        storage.state = {}
    end

    if not storage.state.env then
        storage.state.env = {}
    end
end

local init_settings_player = function(player_index)
    init_settings()
    if not storage.state.players then
        storage.state.players = {}
    end
    if not storage.state.players[player_index] then
        storage.state.players[player_index] = {}
    end
end

local init_settings_force = function(force_index)
    init_settings()
    if not storage.state.forces then
        storage.state.forces = {}
    end
    if not storage.state.forces[force_index] then
        storage.state.forces[force_index] = {}
    end
end

local get_global_player = function(player_index)
    init_settings_player(player_index)
    return storage.state.players[player_index]
end

local request_translations = function(player_index)
    local p = game.get_player(player_index)
    if not p then
        game.print("[RQM] Error: Requested translation but no player found for player_index " .. player_index)
    end
    local f = p.force
    local gp = storage.state.players[player_index]
    gp.translations = {}
    local gpt = storage.state.players[player_index].translations
    gpt.requested = {}
    local gptr = gpt.requested

    local prop = {}

    local att = {"entity", "item", "fluid", "equipment", "recipe", "technology"} -- Needed "quality", "tile"?
    for _, a in pairs(att) do
        for _, t in pairs(prototypes[a]) do
            -- Store the request ID in the requested array and add the type/field identifiers so we can map it easier when we get the translation back 
            local propn = {
                type = a,
                name = t.name,
                field = "localised_name"
            }
            gptr[p.request_translation(t.localised_name)] = propn

            local propd = {
                type = a,
                name = t.name,
                field = "localised_description"
            }
            gptr[p.request_translation(t.localised_description)] = propd

            -- log("Requested: " .. a .. " " .. t.name .. serpent.line(propn) .. " & " .. serpent.line(propd))
        end
    end
end

state.store_translation = function(player_index, id, translated_string)
    local gpt = storage.state.players[player_index].translations
    local gptr = gpt.requested[id]

    -- Early exit if this is an unrequested translation
    if not gptr then
        local str = "[RQM] Error: Received unregistered translation " .. id .. " with translation: " ..
                        (translated_string or "")
        log(str)
    end

    if gpt[gptr.type] == nil or next(gpt[gptr.type]) == nil then
        gpt[gptr.type] = {}
    end
    local gptt = gpt[gptr.type]
    if gptt[gptr.name] == nil or next(gptt[gptr.name]) == nil then
        gptt[gptr.name] = {}
    end

    -- Store the translation
    gptt[gptr.name][gptr.field] = translated_string

    -- Remove the requested ID from the array
    gpt.requested[id] = nil

    -- Check if the requested translation table is empty
    if util.get_array_length(gpt.requested) == 0 then
        game.print("[RQM] Translation complete")
        -- log(serpent.block(gpt))
    end
end

state.get_translation = function(player_index, type, name, field)
    local gp = get_global_player(player_index)
    if not gp then
        return
    end
    local gpt = gp.translations
    if not gpt then
        game.print("[RQM] Error: Unable to search locale, please wait until translations are complete")
        request_translations(player_index)
        return
    end
    local gptt = gpt[type]
    if not gptt then
        return
    end
    local gpttn = gptt[name]
    if not gpttn then
        return
    else
        -- game.print("Requested " .. serpent.line(gpttn))
        return gpttn[field]
    end
end

state.get_player_setting = function(player_index, setting_name)
    local gp = get_global_player(player_index)
    return gp[setting_name]
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

state.get_environment_setting = function(setting_name)
    return storage.state.env[setting_name]
end
state.set_environment_setting = function(setting_name, value)
    storage.state.env[setting_name] = value
end

local set_default_settings_player = function(player_index)
end
local set_default_settings_force = function(player_index)
end
local set_default_environment_variables = function()
    init_settings()

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

    -- TODO: Make array of critical tech
end
state.init = function()
    -- Init
    local forces = {}
    for _, p in pairs(game.players) do
        -- Init the player settings
        init_settings_player(p.index)
        request_translations(p.index)

        -- Add the force to the table (unique)
        util.insert_unique(forces, p.force)
    end

    for _, f in pairs(forces) do
        -- Init the force settings
        init_settings_force(f.index)
    end
    set_default_environment_variables()
end

return state
