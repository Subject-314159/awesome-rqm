local translate = {}

local get_global_player = function(player_index)
    -- init_settings_player(player_index)
    return storage.players[player_index].state
end

translate.request = function(player_index)
    local p = game.get_player(player_index)
    if not p then
        game.print("[RQM] ERROR: Requested translation but no player found for player_index " .. player_index ..
                       ", please open a bug report on the mod portal")
        return
    end
    local f = p.force
    local gp = get_global_player(player_index)
    gp.translations = {}
    local gpt = gp.translations
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
                localised_name = t.localised_name,
                field = "localised_name"
            }
            local idn = p.request_translation(t.localised_name)
            if idn then
                gptr[idn] = propn
            end

            local propd = {
                type = a,
                name = t.name,
                localised_description = t.localised_description,
                field = "localised_description"
            }
            local idd = p.request_translation(t.localised_description)
            if idd then
                gptr[idd] = propd
            end
        end
    end
end

translate.store = function(player_index, id, translated_string, localised_string)
    -- Get the player storage or early exit if we have no translations array
    -- init_settings_player(player_index)
    local gpt = storage.players[player_index].state.translations
    if not gpt then
        return
    end

    -- Early exit if this is an unrequested translation (eg. from other mods)
    local gptr = gpt.requested[id]
    if not gptr or gptr == nil then
        return
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
end

translate.get = function(player_index, type, name, field)
    local gp = get_global_player(player_index)
    if not gp then
        return
    end
    local gpt = gp.translations
    if not gpt then
        game.print("[RQM] ERROR: Unable to search locale, please wait until translations are complete and try again")
        translate.request(player_index)
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
        return gpttn[field]
    end
end

return translate
