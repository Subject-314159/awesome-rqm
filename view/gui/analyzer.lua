local const = require('lib.const')
local util = require('lib.util')
local state = require('model.state')
local tech = require('model.tech')
local queue = require('model.queue')
local lab = requier('model.lab')

local analyzer = {}

--------------------------------------------------------------------------------
--- Retrieve state
--------------------------------------------------------------------------------

local get_tech_without_prerequisites = function(force_index)
    -- Get Storage Force and sfName
    -- local ssf = get_force(force_index)
    -- local ssft = ssf.technology
    local tsx = tech.get_all_tech_state_ext(force_index)

    local tech = {}
    for tech_name, xcur in pairs(tsx) do
        if not xcur.meta.has_prerequisites then
            table.insert(tech, tech_name)
        end
    end
    return tech
end

local get_entry_technologies = function(force_index)
    -- Get Storage Force and sfName
    -- local ssf = get_force(force_index)
    -- local ssft = ssf.technology
    local tsx = tech.get_all_tech_state_ext(force_index)

    local entry = {}
    for tech_name, xcur in pairs(tsx) do
        if xcur.available and not xcur.technology.researched then
            table.insert(entry, tech_name)
        end
    end
    return entry
end

local get_unresearched_technologies_ordered = function(force_index)
    -- Get Storage Force and sfName
    local tsx = tech.get_all_tech_state_ext(force_index)

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
        local xcur = tsx[tech]
        if not xcur.technology.researched then
            table.insert(techlist, tech)
        end
        visited[tech] = true

        -- Propagate properties to each successor
        for suc, _ in pairs(xcur.technology.successors or {}) do
            local xsuc = tsx[suc]

            -- Check if we can visit this successor next
            local suitable = true
            for pre, _ in pairs(xsuc.technology.prerequisites or {}) do
                -- local xpre = tsx[pre]
                suitable = suitable and (visited[pre] or omit[pre])
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

--------------------------------------------------------------------------------
--- Queue
--------------------------------------------------------------------------------

analyzer.get_queue_meta = function(force_index) -- This function recalculates the ingame queue, i.e. add metadata
    -- Early exit if we don't have a queue
    local f = game.forces[force_index]
    if not f then
        return
    end
    local sfq = queue.get_queue(f.index)
    if not sfq or #sfq == 0 then
        return
    end

    local qms = queue.get_tech_missing_science(f.index)
    local lsci = lab.get_labs_fill_rate(f.index)
    local researching = queue.get_current_researching(f.index)

    -- local meta = analyzer.get_tech_meta(force_index)
    local tsx = tech.get_all_tech_state_ext(force_index)

    -- TODO: Clear any remaining technology that was finished in the meantime --> In a different function
    local rolling_queue = {}
    local rolling_inherit = {}
    local res = {}
    for _, q in pairs(sfq) do
        local rcur = {
            tech_name = q
        }
        local xcur = tsx[q]
        -- Get the technology state
        -- local et = state.get_technology(f.index, q.technology_name)

        -- Init empty arrays
        local arr = {"blocking_reasons", "entry_nodes", "new_unblocked", "inherit_unblocked", "all_unblocked",
                     "new_blocked", "inherit_blocked", "all_blocked", "inherit_by"}
        for _, prop in pairs(arr) do
            rcur[prop] = {}
        end

        -- Get inherit: if one of the prior queued tech is a successor of the current tech then it is inherited by the prior queued tech
        for _, rq in pairs(rolling_queue) do
            if xcur.meta.all_successors[rq] then
                table.insert(rcur.inherit_by, rq)
            end
        end
        rcur.is_inherited = (#rcur.inherit_by > 0)

        -- Mark self as blocking
        if (not xcur.technology.enabled or xcur.meta.hidden) then
            rcur.is_blocked = true
            -- Init reason array
            local reason = "tech_is_not_enabled"
            if not rcur.blocking_reasons[reason] then
                rcur.blocking_reasons[reason] = {}
            end
            -- Add to metadata
            table.insert(rcur.blocking_reasons[reason], xcur.technology.name)
        end

        -- Mark & list missing science
        if qms[q] then
            rcur.misses_science = true
            -- List all missing sciences
            rcur.missing_science = {}
            for _,s in pairs(xcur.meta.sciences or {}) do
                if not lsci[s]>0 then rcur.missing_science[s]=true end
            end
            for pre, _ in pairs(xcur.meta.all_prerequisites or {}) do
                local xpre = tsx[pre]
                for _,s in pairs(xpre.meta.sciences or {}) do
                    if not lsci[s]>0 then rcur.missing_science[s]=true end
                end
            end
        end

        -- Mark being researched
        if q == researching then
            rcur.is_researching = true
        end

        -- Get specific prerequisites properties
        for pre, _ in pairs(xcur.meta.all_prerequisites or {}) do
            -- Get the prerequisite state
            -- local pt = state.get_technology(f.index, pre)
            local xpre = tsx[pre]
            if xpre.technology.researched then
                -- Skip this prerequisite as it is already researched
                goto continue
            end

            -- Get array of prerequisites by new/inherit/all un-/blocked
            local is_new = util.array_has_value(rolling_inherit, pre)
            if xpre.meta.has_trigger or not xpre.technology.enabled or xpre.meta.hidden or next(xpre.blocked_by) ~= nil or
                next(xpre.disabled_by) ~= nil then
                -- if pt.has_trigger or not pt.technology.enabled or pt.hidden or pt.blocked_by then
                if is_new then
                    table.insert(rcur.new_blocked, pre)
                else
                    table.insert(rcur.inherit_blocked, pre)
                end
                table.insert(rcur.all_blocked, pre)
                rcur.is_blocked = true
            else
                if is_new then
                    table.insert(rcur.new_unblocked, pre)
                else
                    table.insert(rcur.inherit_unblocked, pre)
                end
                table.insert(rcur.all_unblocked, pre)
            end

            -- Get blocked tech
            -- Trigger tech
            if xpre.meta.has_trigger then
                -- Init reason array
                local reason = "tech_is_manual_trigger"
                if not rcur.blocking_reasons[reason] then
                    rcur.blocking_reasons[reason] = {}
                end
                -- Add to metadata
                table.insert(rcur.blocking_reasons[reason], pre)
            end

            -- Disabled/hidden tech
            if not xpre.technology.enabled or xpre.meta.hidden then
                -- Init reason array
                local reason = "tech_is_not_enabled"
                if not rcur.blocking_reasons[reason] then
                    rcur.blocking_reasons[reason] = {}
                end
                -- Add to metadata
                table.insert(rcur.blocking_reasons[reason], pre)
            end

            -- Append prerequisite to rolling inherit array
            if is_new then
                table.insert(rolling_inherit, pre)
            end

            ::continue::
        end
        rcur.all_predecessors = xcur.meta.all_prerequisites

        -- Add the current queued tech to the rolling tech array
        table.insert(res, rcur)
        table.insert(rolling_queue, q)
    end
    return res
end

--------------------------------------------------------------------------------
--- Tech list
--------------------------------------------------------------------------------

local tech_matches_search_text = function(player_index, tech)
    local p = game.get_player(player_index)
    local f = p.force
    local technology = f.technologies[tech]

    -- Get the search text (or return true if no search)
    local needle = state.get_player_setting(player_index, "search_text")
    -- local ssp = storage.state.players[player_index]
    -- local needle = ssp["search_text"]
    if not needle or needle == "" then
        return true
    end

    -- Find the text in the tech
    local haystack = {state.get_translation(p.index, "technology", technology.name, "localised_name"),
                      state.get_translation(p.index, "technology", technology.name, "localised_description")}
    -- local use_manual_map = state.get_player_setting(player_index, "use_manual_lowercase_map",
    --     const.default_settings.player.use_manual_lowercase_map)
    local use_manual_map = settings.get_player_settings(p.index)["rqm-player_use-manual-character-mapping"].value
    if needle and needle ~= "" and util.fuzzy_search(needle, haystack, nil, use_manual_map) then
        return true
    end

    -- Fallback text not found
    return false
end

local get_tech_filtered = function(player_index, filter)
    -- Get Storage Force and sfName
    local p = game.get_player(player_index)
    local f = p.force
    local tsx = tech.get_all_tech_state_ext(f.index)

    -- log("=== tsx ===")
    -- log(serpent.block(tsx))

    local techlist = get_unresearched_technologies_ordered(f.index)
    local filtered_tech = {}

    for _, tech in pairs(techlist) do
        local xcur = tsx[tech]
        if not filter then
            goto skip_filter
        end

        -- Filter 0: Search text (do this one first because it will filter out the most sciences)
        if filter.search_text and filter.search_text ~= "" and not tech_matches_search_text(player_index, tech) then
            goto continue
        end

        -- Filter 1: Matches required sciences (do this one second because it will filter out a lot of sciences)
        if #filter.allowed_sciences > 0 and
            not util.array_has_all_values(filter.allowed_sciences, (xcur.meta.sciences or {})) then
            goto continue
        end

        -- Filter 2: Disabled/hidden tech
        if filter.hide_tech["disabled_tech"] and (not xcur.technology.enabled or xcur.meta.hidden) then
            goto continue
        end

        -- Filter 3: Manual trigger tech
        if filter.hide_tech["manual_trigger_tech"] and xcur.meta.has_trigger then
            goto continue
        end

        -- Filter 4: Infinite tech
        if filter.hide_tech["infinite_tech"] and xcur.meta.is_infinite then
            goto continue
        end

        -- Filter 5: Inherited tech
        if filter.hide_tech["inherited_tech"] and (next(xcur.inherited_by) ~= nil or xcur.queued) then
            goto continue
        end

        -- Filter 6: Unavailable successors
        if filter.hide_tech["unavailable_successors"] and
            (next(xcur.blocked_by) ~= nil or next(xcur.disabled_by) ~= nil) then
            goto continue
        end

        -- Filter 7: Show category
        if filter.show_tech ~= "all" then
            if filter.show_tech == "essential" then
                if not xcur.meta.prototype.essential then
                    goto continue
                end
            elseif filter.show_tech == "infinite" then
                if not xcur.meta.is_infinite then
                    goto continue
                end
            else
                -- Check if any of this category's prototypes or effects match any of the given tech's prototypes or effects
                for type, prop in pairs(const.categories[filter.show_tech]) do
                    if xcur.meta[type] then
                        for _, p in pairs(prop) do
                            if xcur.meta[type][p] then
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
        table.insert(filtered_tech, xcur)
        if xcur.technology.name == "follower-robot-count-3" then
        end

        ::continue::
    end

    -- log("=== filtered_tech ===")
    -- log(serpent.block(filtered_tech))

    return filtered_tech

end

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
    return get_tech_filtered(player_index, filter)
end

return analyzer
