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
        storage.settings.players[force_index] = {}
    end
end

local get_global_player = function(player_index)
    init_settings_player(player_index)
    return storage.settings.players[player_index]
end

settings.get_search_is_focussed = function(player_index)
    local gp = get_global_player(player_index)
    return gp.search_is_focussed
end

return settings
