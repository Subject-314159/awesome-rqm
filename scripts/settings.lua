local settings = {}

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
    local gptr = gptt.requested

    for _, t in pairs (force.technology) do
       --Store the request ID in the requested array and add the type/field identifiers so we can map it easier when we get the translation back 
        gptr[p.request_translation(t.localised_name)] = {type="technology",field="localised_name",name=t.name}
        gptr[p.request_translation(t.localised_description)] = {type="technology",field="localised_description",name=t.name}
    end
end

settings.store_translation = function(player_index, id, translated_string)
    local gpt = storage.settings.players[player_index].translations
    local gptr = gpt.requested
    local prop = gptr[id]
    if not gpt[prop.type] or next(gpt[prop.type]) == nil then
        gpt[prop.type] = {}
    end
    local gptt = gpt[prop.type]
    --TODO: Store the translation in the array and delete the requested ID
end

settings.init = function()
    for _,p in pairs (game.players) do
        init_settings_player(p.index)
        request_translations(p.index)
    end
end

return settings
