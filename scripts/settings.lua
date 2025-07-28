local settings = {}

local util = require('util')

local init_settings = function()
    if not storage then
        storage = {}
    end
    if not storage.settings then
        storage.settings = {}
    end
end

local init_settings_player = function(player_index)
    init_settings()
    if not storage.settings.players then
        storage.settings.players = {}
    end
    if not storage.settings.players[player_index] then
        storage.settings.players[player_index] = {}
    end
end

local init_settings_force = function(force_index)
    init_settings()
    if not storage.settings.forces then
        storage.settings.forces = {}
    end
    if not storage.settings.forces[force_index] then
        storage.settings.force[force_index] = {}
    end
end

local get_global_player = function(player_index)
    init_settings_player(player_index)
    return storage.settings.players[player_index]
end

local request_translations = function(player_index)
    local p = game.get_player(player_index)
    local f = p.force
    local gp = storage.settings.players[player_index]
    gp.translations = {}
    local gpt = storage.settings.players[player_index].translations
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

            log("Requested: " .. a .. " " .. t.name .. serpent.line(propn) .. " & " .. serpent.line(propd))
        end
    end
end

settings.store_translation = function(player_index, id, translated_string)
    local gpt = storage.settings.players[player_index].translations
    local gptr = gpt.requested[id]

    -- Early exit if this is an unrequested translation
    if not gptr then
        local str = "RQM Error: Received unregistered translation " .. id .. " with translation: " ..
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
        game.print("Translation complete")
        log("Translation complete")
        log(serpent.block(gpt))
    end
end

settings.init = function()
    for _, p in pairs(game.players) do
        init_settings_player(p.index)
        request_translations(p.index)
    end
end

return settings
