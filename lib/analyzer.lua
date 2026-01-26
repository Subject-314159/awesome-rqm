-- The analyzer can read from all storage but it does not write to storage
-- The goal of the analyzer is to make information from data
local state = require("lib.state")
local util = require("lib.util")
local const = require("lib.const")
local translate = require("lib.state.translate")

local analyzer = {}

local get_env = function()
    return state.get_environment_setting("tech_env")
end

local get_queue = function(force_index)
    return storage.queue.forces[force_index]
end

----------------------------------------------------------------------------------------------------
-- Tech generic (internal)
----------------------------------------------------------------------------------------------------

local get_tech_without_prerequisites = function(force_index)
    local f = game.forces[force_index]
    local arr = {}
    for t, tech in pairs(f.technologies or {}) do
        log(t)
        if tech.prerequisites == nil or next(tech.prerequisites) == nil then
            -- table.insert(arr, t)
            arr[tech.name] = true
        end
    end
    log(force_index .. " - Tech without predecessors: " .. serpent.block(arr))
    return arr
end

local get_entry_technologies = function(force_index)
    local f = game.forces[force_index]
    local arr = {}
    for _, tech in pairs(f.technologies) do
        if analyzer.tech_is_available(tech) then
            -- table.insert(arr, tech.name)
            arr[tech.name] = true
        end
    end
    return arr
end

local get_unresearched_trigger_technologies = function(force_index)
    local env = get_env()
    local f = game.forces[force_index]
    local arr = {}

    for _, tech in pairs(f.technologies) do
        local et = env[tech.name]
        if et and et.has_trigger and not tech.researched then
            -- table.insert(arr, tech.name)
            arr[tech.name] = true
        end
    end
    return arr
end

local get_unresearched_disabled_technologies = function(force_index)
    local env = get_env()
    local f = game.forces[force_index]
    local arr = {}

    for _, tech in pairs(f.technologies) do
        local et = env[tech.name]
        if et and (et.hidden or not tech.enabled) and not tech.researched then
            -- table.insert(arr, tech.name)
            arr[tech.name] = true
        end
    end
    return arr
end

--------------------------------------------------------------------------------
--- Generic meta
--------------------------------------------------------------------------------

analyzer.get_filtered_technologies_player = function(player_index)
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
    return analyzer.get_filtered_meta_player(player_index, filter)
end

analyzer.get_tech_meta = function(force_index)
    local f = game.forces[force_index]
    local env = get_env()

    -- Get all queued tech and their inherited prerequisites
    local queue = get_queue(force_index)
    local all_queued_inherited = {}
    for q, _ in pairs(queue or {}) do
        if not env[q] then
            goto continue
        end
        all_queued_inherited[q] = true
        for pre, _ in pairs(env[q].all_prerequisites or {}) do
            all_queued_inherited[pre] = true
        end
        ::continue::
    end

    -- Get all blocking/disabled tech
    local all_trigger_tech = get_unresearched_trigger_technologies(force_index)
    local all_disabled_tech = get_unresearched_disabled_technologies(force_index)

    local arr = {}
    for name, tech in pairs(f.technologies) do
        local et = env[tech.name]
        arr[name] = {
            tech_name = name,
            is_researched = tech.researched,
            is_blocking = et.has_trigger,
            is_avalable = analyzer.tech_is_available(tech),
            is_disabled = et.hidden or not tech.enabled,
            is_infinite = et.is_infinite,
            is_inherited = (all_queued_inherited[name] and not tech.researched),
            is_essential = et.essential,
            is_unavailable_successor = false, -- To be updated dynamically
            research_trigger = et.research_trigger,
            all_prerequisites = util.deepcopy(et.all_prerequisites), -- TODO figure out if deepcopy is necessary
            all_successors = util.deepcopy(et.all_successors),
            -- blocking_prerequisites = util.deepcopy(et.blocking_prerequisites), -- TODO figure out if deepcopy is necessary // figure out if this is arry necessary
            sciences = et.sciences,
            blocked_by = {},
            disabled_by = {}
        }

        -- Remove researched (blocking) prerequisites
        -- remove_researched(arr.all_prerequisites)
        -- remove_researched(arr.blocking_prerequisites)

        -- Check if this is an unavailable successor
        for p, _ in pairs(et.all_prerequisites) do
            if all_trigger_tech[p] then
                arr[name].blocked_by[p] = true
                arr[name].is_unavailable_successor = true
            end
            if all_disabled_tech[p] then
                arr[name].disabled_by[p] = true
                arr[name].is_unavailable_successor = true
            end
        end
        -- is_blocked_successor = (all_trigger_tech[name] and not tech.researched),
        -- is_disabled_successor = (all_disabled_tech[name] and not tech.researched),
    end
    return arr
end

local get_unresearched_technologies_ordered = function(force_index)
    -- Get some variables to work with
    local f = game.forces[force_index]
    local techlist, queue, visited = {}, {}, {}

    -- Get entry tech
    local start_tech = get_tech_without_prerequisites(force_index)
    for t, _ in pairs(start_tech) do
        table.insert(queue, t)
    end

    -- BFS all successors
    while #queue > 0 do
        -- Get the first next unvisited tech from the queue
        local tn = table.remove(queue, 1)
        if visited[tn] then
            goto continue
        end

        -- Add the tech to our final array if it is not yet researched
        local tech = f.technologies[tn]
        if not tech.researched then
            table.insert(techlist, tn)
        end
        visited[tn] = true

        -- Propagate properties to each successor
        for _, suc in pairs(tech.successors or {}) do

            -- Check if we can visit this successor next
            local suitable = true
            for tp, _ in pairs(suc.prerequisites or {}) do
                suitable = suitable and visited[tp]
            end
            if suitable then
                table.insert(queue, suc.name)
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
    local ssp = storage.state.players[player_index]
    local needle = ssp["search_text"]
    if not needle or needle == "" then
        return true
    end

    -- Find the text in the tech
    local haystack = {translate.get(p.index, "technology", technology.name, "localised_name"),
                      translate.get(p.index, "technology", technology.name, "localised_description")}
    local use_manual_map = settings.get_player_settings(p.index)["rqm-player_use-manual-character-mapping"].value
    if needle and needle ~= "" and util.fuzzy_search(needle, haystack, nil, use_manual_map) then
        return true
    end

    -- Fallback text not found
    return false
end

analyzer.get_filtered_meta_player = function(player_index, filter)
    -- Get Storage Force and sfName
    local p = game.get_player(player_index)
    local f = p.force
    local meta = analyzer.get_tech_meta(f.index)
    local env = get_env()

    local techlist = get_unresearched_technologies_ordered(f.index)
    log(serpent.block(techlist))
    local filtered_tech = {}

    for _, tech in pairs(techlist) do
        -- Show this tech if there is no filter or skip this tech if we don't have metadata
        if not filter then
            goto skip_filter
        end
        if not meta[tech] or not env[tech] then
            goto continue
        end

        -- Filter 0: Search text (do this one first because it will filter out the most sciences)
        if filter.search_text and filter.search_text ~= "" and not tech_matches_search_text(player_index, tech) then
            goto continue
        end

        -- Filter 1: Matches required sciences (do this one second because it will filter out a lot of sciences)
        if #filter.allowed_sciences > 0 and
            not util.array_has_all_values(filter.allowed_sciences, (env[tech].sciences or {})) then
            goto continue
        end

        -- Filter 2: Disabled/hidden tech
        if filter.hide_tech["disabled_tech"] and meta[tech].is_disabled then
            goto continue
        end

        -- Filter 3: Manual trigger tech
        if filter.hide_tech["manual_trigger_tech"] and meta[tech].is_blocking then
            goto continue
        end

        -- Filter 4: Infinite tech
        if filter.hide_tech["infinite_tech"] and meta[tech].is_infinite then
            goto continue
        end

        -- Filter 5: Inherited tech
        if filter.hide_tech["inherited_tech"] and meta[tech].is_inherited then
            goto continue
        end

        -- Filter 6: Unavailable successors
        if filter.hide_tech["unavailable_successors"] and meta[tech].is_unavailable_successor then
            goto continue
        end

        -- Filter 7: Show category
        if filter.show_tech ~= "all" then
            if filter.show_tech == "essential" then
                if not meta[tech].is_essential then
                    goto continue
                end
            else
                -- Check if any of this category's prototypes or effects match any of the given tech's prototypes or effects
                for type, prop in pairs(const.categories[filter.show_tech]) do
                    if env[tech][type] then
                        for _, p in pairs(prop) do
                            if env[tech][type][p] then
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
        -- table.insert(filtered_tech, tech)
        filtered_tech[tech] = meta[tech]

        ::continue::
    end

    log("=== filtered_tech ===")
    log(serpent.block(filtered_tech))
    return filtered_tech
end

--------------------------------------------------------------------------------
--- Queue
--------------------------------------------------------------------------------

analyzer.get_queue_meta = function(force_index) -- This function recalculates the ingame queue, i.e. add metadata
    -- Early exit if we don't have a queue
    local f = game.forces[force_index]
    if not f then
        return
    end
    local queue = get_queue(f.index)
    if not queue or #queue == 0 then
        return
    end
    local meta = analyzer.get_tech_meta(force_index)

    -- TODO: Clear any remaining technology that was finished in the meantime --> In a different function
    local rolling_queue = {}
    local rolling_inherit = {}
    local res = {}
    for _, q in pairs(queue) do
        local cur = {
            tech_name = q
        }
        -- Get the technology state
        -- local et = state.get_technology(f.index, q.technology_name)

        -- Init empty arrays
        local arr = {"blocking_reasons", "entry_nodes", "new_unblocked", "inherit_unblocked", "all_unblocked",
                     "new_blocked", "inherit_blocked", "all_blocked", "inherit_by"}
        for _, prop in pairs(arr) do
            cur[prop] = {}
        end

        -- Get inherit: if one of the prior queued tech is a successor of the current tech then it is inherited by the prior queued tech
        for _, rq in pairs(rolling_queue) do
            if meta[q].all_successors[rq] then
                table.insert(cur.inherit_by, rq)
            end
        end
        cur.is_inherited = (#cur.inherit_by > 0)

        -- Get specific prerequisites properties
        for pre, _ in pairs(meta[q].all_prerequisites or {}) do
            -- Get the prerequisite state
            -- local pt = state.get_technology(f.index, pre)
            if meta[q].is_researched then
                -- Skip this prerequisite as it is already researched
                goto continue
            end

            -- Get array of prerequisites by new/inherit/all un-/blocked
            local is_new = util.array_has_value(rolling_inherit, pre)
            if meta[q].is_blocking or not meta[q].enabled or meta[q].hidden or meta[q].blocked_by or meta[q].disabled_by then
                -- if pt.has_trigger or not pt.technology.enabled or pt.hidden or pt.blocked_by then
                if is_new then
                    table.insert(cur.new_blocked, pre)
                else
                    table.insert(cur.inherit_blocked, pre)
                end
                table.insert(cur.all_blocked, pre)
                cur.is_blocked = true
            else
                if is_new then
                    table.insert(cur.new_unblocked, pre)
                else
                    table.insert(cur.inherit_unblocked, pre)
                end
                table.insert(cur.all_unblocked, pre)
            end

            -- Get blocked tech
            -- Trigger tech
            if meta[q].is_blocking then
                -- Init reason array
                local reason = "tech_is_manual_trigger"
                if not cur.blocking_reasons[reason] then
                    cur.blocking_reasons[reason] = {}
                end
                -- Add to metadata
                table.insert(cur.blocking_reasons[reason], pre)
            end

            -- Disabled/hidden tech
            if not meta[q].enabled or meta[q].hidden then
                -- Init reason array
                local reason = "tech_is_not_enabled"
                if not cur.blocking_reasons[reason] then
                    cur.blocking_reasons[reason] = {}
                end
                -- Add to metadata
                table.insert(cur.blocking_reasons[reason], pre)
            end

            -- Append prerequisite to rolling inherit array
            if is_new then
                table.insert(rolling_inherit, pre)
            end

            ::continue::
        end
        cur.all_predecessors = meta[q].all_prerequisites

        -- Add the current queued tech to the rolling tech array
        table.insert(res, cur)
        table.insert(rolling_queue, q)
    end
    return res
end

analyzer.get_first_next_tech = function(force_index)
    local f = game.forces[force_index]
    local env = get_env()
    local queue = get_queue(force_index)
    -- local all_available = analyzer.get_entry_technologies(force_index)

    for _, q in pairs(queue) do
        local et = env[q]
        local tech = f.technologies[q]
        -- local t = state.get_technology(force_index, q.technology_name)

        if analyzer.tech_is_available(tech) and not et.has_trigger then
            return q
        else
            for p, _ in pairs(et.all_prerequisites or {}) do
                local ep = env[q]
                local ptech = f.technologies[p]
                if analyzer.tech_is_available(ptech) and not ep.has_trigger then
                    -- if all_available[ptech] and not pt.has_trigger then
                    return p.name
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
--- Public single tech checks
--------------------------------------------------------------------------------

---@param tech LuaTechnology
analyzer.tech_is_infinite = function(tech)
    local env = get_env()
    if not env[tech_name] then
        return false
    end
    return env[tech_name].is_infinite
end
---@param tech LuaTechnology
analyzer.tech_is_available = function(tech)
    -- Early exit on invalid or already researched tech
    if not tech or not tech.valid or tech.researched then
        return false
    end

    -- Current tech is available if all prerequisites are researched
    local available = true
    for _, p in pairs(tech.prerequisites or {}) do
        available = available and p.researched
    end
    return available
end

---@param tech LuaTechnology
analyzer.tech_is_disabled = function(tech)
    local env = get_env()
    if not env[tech_name] then
        return false
    end
    return (env[tech.name] and not tech.enabled and not tech.researched)
end

return analyzer
