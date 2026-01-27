local const = require('lib.const')
local util = require('lib.util')
local state = require('lib.state')

local analyzer = {}

--------------------------------------------------------------------------------
--- Retrieve state
--------------------------------------------------------------------------------

local get_tech_without_prerequisites = function(force_index)
    -- Get Storage Force and sfName
    local ssf = get_force(force_index)
    local ssft = ssf.technology

    local tech = {}
    for t, prop in pairs(ssft) do
        if not prop.has_prerequisites then
            table.insert(tech, t)
        end
    end
    return tech
end

local get_entry_technologies = function(force_index)
    -- Get Storage Force and sfName
    local ssf = get_force(force_index)
    local ssft = ssf.technology

    local entry = {}
    for t, prop in pairs(ssft) do
        if prop.available and not prop.technology.researched then
            table.insert(entry, t)
        end
    end
    return entry
end

stech.get_technology = function(force_index, technology_name)
    -- Get Storage Force and sfName
    local ssf = get_force(force_index)
    local ssft = ssf.technology
    local ssftn = ssft[technology_name]
    return ssftn
end

stech.get_unresearched_technologies_ordered = function(force_index)
    -- Get Storage Force and sfName
    local ssf = get_force(force_index)
    local ssft = ssf.technology

    -- Get entry tech
    local entry_tech = get_entry_technologies(force_index)
    local start_tech = get_tech_without_prerequisites(force_index)

    local techlist, queue, visited, omit = {}, {}, {}, {}

    for _, t in pairs(entry_tech) do
        table.insert(queue, t)
    end
    for _, t in pairs(start_tech) do
        table.insert(queue, t)
    end

    -- for _, t in pairs(entry_tech) do
    --     table.insert(queue, t)
    --     for s, _ in pairs(ssft[t].successors or {}) do
    --         for p, _ in pairs(ssft[s].prerequisites) do
    --             if not util.array_has_value(entry_tech, p) then
    --                 omit[p] = true
    --             end
    --         end
    --     end
    -- end

    while #queue > 0 do
        -- Get the first next unvisited tech from the queue
        local tech = table.remove(queue, 1)
        if visited[tech] then
            goto continue
        end

        -- Add the tech toour final array if it is not yet researched
        local t = ssft[tech]
        if not t.technology.researched then
            table.insert(techlist, tech)
        end
        visited[tech] = true

        -- Propagate properties to each successor
        for suc, _ in pairs(t.successors or {}) do
            local ts = ssft[suc]

            -- Check if we can visit this successor next
            local suitable = true
            for tp, _ in pairs(ts.prerequisites or {}) do
                local pre = ssft[tp]
                suitable = suitable and (visited[tp] or omit[tp])
            end
            if suitable then
                table.insert(queue, suc)
            else
            end
        end

        ::continue::
    end

    return techlist
end

local tech_matches_search_text = function(player_index, tech)
    local p = game.get_player(player_index)
    local f = p.force
    local technology = f.technologies[tech]

    -- Get the search text (or return true if no search)
    -- local needle = state.get_player_setting(player_index, "search_text")
    local ssp = storage.state.players[player_index]
    local needle = ssp["search_text"]
    if not needle or needle == "" then
        return true
    end

    -- Find the text in the tech
    local haystack = {translate.get(p.index, "technology", technology.name, "localised_name"),
                      translate.get(p.index, "technology", technology.name, "localised_description")}
    -- local use_manual_map = state.get_player_setting(player_index, "use_manual_lowercase_map",
    --     const.default_settings.player.use_manual_lowercase_map)
    local use_manual_map = settings.get_player_settings(p.index)["rqm-player_use-manual-character-mapping"].value
    if needle and needle ~= "" and util.fuzzy_search(needle, haystack, nil, use_manual_map) then
        return true
    end

    -- Fallback text not found
    return false
end

analyzer.get_filtered_technologies_player = function(player_index, filter)
    -- Get Storage Force and sfName
    local p = game.get_player(player_index)
    local f = p.force
    local ssf = get_force(f.index)
    local ssft = ssf.technology

    local techlist = stech.get_unresearched_technologies_ordered(f.index)
    local filtered_tech = {}

    for _, tech in pairs(techlist) do
        local ssftt = ssft[tech]
        if not filter then
            goto skip_filter
        end

        -- Filter 0: Search text (do this one first because it will filter out the most sciences)
        if filter.search_text and filter.search_text ~= "" and not tech_matches_search_text(player_index, tech) then
            goto continue
        end

        -- Filter 1: Matches required sciences (do this one second because it will filter out a lot of sciences)
        if #filter.allowed_sciences > 0 and
            not util.array_has_all_values(filter.allowed_sciences, (ssftt.sciences or {})) then
            goto continue
        end

        -- Filter 2: Disabled/hidden tech
        if filter.hide_tech["disabled_tech"] and (not ssftt.technology.enabled or ssftt.hidden) then
            goto continue
        end

        -- Filter 3: Manual trigger tech
        if filter.hide_tech["manual_trigger_tech"] and ssftt.has_trigger then
            goto continue
        end

        -- Filter 4: Infinite tech
        if filter.hide_tech["infinite_tech"] and ssftt.is_infinite then
            goto continue
        end

        -- Filter 5: Inherited tech
        if filter.hide_tech["inherited_tech"] and (ssftt.inherited_by ~= nil or ssftt.queued) then
            goto continue
        end

        -- Filter 6: Unavailable successors
        if filter.hide_tech["unavailable_successors"] and (ssftt.blocked_by ~= nil or ssftt.disabled_by ~= nil) then
            goto continue
        end

        -- Filter 7: Show category
        if filter.show_tech ~= "all" then
            if filter.show_tech == "essential" then
                if not ssftt.essential then
                    goto continue
                end
            else
                -- Check if any of this category's prototypes or effects match any of the given tech's prototypes or effects
                for type, prop in pairs(const.categories[filter.show_tech]) do
                    if ssftt[type] then
                        for _, p in pairs(prop) do
                            if ssftt[type][p] then
                                -- There is a match, no need to look further
                                goto skip_filter
                            end
                        end
                    end
                end
                goto continue
            end
        end

        ::skip_filter::
        -- If we passed all the filters, add the science to our return array
        table.insert(filtered_tech, tech)

        ::continue::
    end

    return filtered_tech

end

return analyzer
