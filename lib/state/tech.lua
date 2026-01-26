local const = require("lib.const")
local util = require("lib.util")
local translate = require("lib.state.translate")

-- This module is only to be required in state and to be treated as an extension
local stech = {}

local TECHNOLOGY_PROPERTIES = "technology_properties"

--------------------------------------------------------------------------------
--- Generic
--------------------------------------------------------------------------------

-- Data model
-- local storage.state.env[TECHNOLOGY_PROPERTIES] = {
--     [tech_name] = {
--         -- From prototype
--         enabled = bool
--         has_trigger = bool
--         is_infinite = bool
--         sciences = {"science-name", ...}
--         predecessors = {[tech_name] = bool, ...}
--         successors = {[tech_name] = bool, ...}
--         research_trigger = ResearchTrigger
--         order = string
--         hidden = bool
--         -- From runtime
--         technology = LuaTechnology
--         enabled = bool
--         researched = bool
--         queued = bool
--         available = bool
--         -- Propagated
--         blocked_by = {[tech_name] = bool, ...}
--         disabled_by = {[tech_name] = bool, ...}
--         blocked_prerequisites = {[tech_name] = bool, ...}
--         unblocked_prerequisites = {[tech_name] = bool, ...}
--         all_prerequisites = {[tech_name] = bool, ...}
--         inherited_by = {[tech_name] = bool, ...}
--         entry_nodes = {[tech_name] = bool, ...}
--     }
-- }

local get_env = function()
    return storage.state.env[TECHNOLOGY_PROPERTIES]
end
local get_force = function(force_index)
    return storage.state.forces[force_index]
end
local get_simple_queue = function(force_index)
    if not storage.forces then
        return {}
    end
    local sf = storage.forces[force_index]
    if not sf or not sf.simple_queue then
        -- Queue is not yet initialized, return empty array
        return {}
    end
    return sf.simple_queue
end

local get_allowed_prototype = function(proto)
    for _, prop in pairs(const.categories) do
        for _, pt in pairs(prop.prototypes or {}) do
            if pt == proto.type then
                return proto.type
            end
        end
    end
end

local get_prototypes = function(effect)
    local has_recipe = {
        ["change-recipe-productivity"] = true,
        ["unlock-recipe"] = true
    }
    local has_item = {
        ["give-item-modifier"] = true
    }
    local prots = {}
    local items = {}

    -- Get the items from the recipe
    if has_recipe[effect.type] then
        local r = prototypes.recipe[effect.recipe]
        for _, p in pairs(r.products) do
            if p.type == "item" then
                table.insert(items, p.name)
            end
        end
    end

    -- Get the item
    if has_item[effect.type] then
        table.insert(items, effect.item)
    end

    -- Search for the actual prototypes based on the items
    if #items > 0 then
        for _, itm in pairs(items) do
            -- Get the item prototype
            local ip = prototypes.item[itm]
            local proto = get_allowed_prototype(ip)

            if proto then
                table.insert(prots, proto)
            end

            -- Get the prototype of the place result
            if ip.place_result then
                table.insert(prots, ip.place_result.type)
            end
        end
    end

    -- Return the array with all prototypes associated with this effect
    return prots
end

stech.init_env = function()
    local tech_env = {}
    for name, t in pairs(prototypes.technology) do
        -- Init/get the empty tech array
        if not tech_env[name] then
            tech_env[name] = {}
        end
        local tn = tech_env[name]

        -- Copy standard properties
        tn.has_trigger = (t.research_trigger ~= nil)
        tn.research_trigger = t.research_trigger
        tn.is_infinite = t.max_level >= 4294960000
        tn.essential = t.essential
        tn.order = t.order
        tn.hidden = t.hidden

        -- Effects and prototypes associated with this tech
        tn.research_effects = {}
        tn.research_prototypes = {}
        for _, effect in pairs(t.effects or {}) do
            tn.research_effects[effect.type] = true
            local prototypes = get_prototypes(effect)
            for _, proto in pairs(prototypes) do
                tn.research_prototypes[proto] = true
            end
        end

        -- Add sciences
        local s = {}
        for _, rui in pairs(t.research_unit_ingredients or {}) do
            table.insert(s, rui.name)
        end
        if #s > 0 then
            tn.sciences = s
        end

        -- Copy successors
        tn.successors = {}
        tn.has_successors = false
        for s, _ in pairs(t.successors) do
            tn.successors[s] = true
            tn.has_successors = true
        end

        -- Copy predecessors
        tn.prerequisites = {}
        tn.has_prerequisites = false
        local queue = {}
        for s, _ in pairs(t.prerequisites) do
            tn.prerequisites[s] = true
            tn.has_prerequisites = true
            table.insert(queue, s)
        end

        -- Get all prerequisites
        tn.all_prerequisites = {}
        tn.blocking_prerequisites = {}
        while #queue > 0 do
            -- Get first next unvisited tech
            local tech = table.remove(queue, 1)
            if tn.all_prerequisites[tech] then
                goto continue
            end
            local prot = prototypes.technology[tech]

            -- Mark current tech visited
            tn.all_prerequisites[tech] = true

            -- Mark current tech as blocking
            if prot.research_trigger ~= nil then
                tn.blocking_prerequisites[tech] = true
            end

            -- Add all unvisited predecessors of current tech to the queue
            for s, _ in pairs(prot.prerequisites or {}) do
                if not tn.all_prerequisites[s] then
                    table.insert(queue, s)
                end
            end

            ::continue::
        end
    end

    -- Store the technology properties in environment
    storage.state.env[TECHNOLOGY_PROPERTIES] = tech_env
end

--------------------------------------------------------------------------------
--- Retrieve state
--------------------------------------------------------------------------------

---@param tech LuaTechnology
local tech_is_available = function(tech)
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

local tech_is_triger = function(tech)
    local env = get_env()
    local et = env[tech.name]
    if et and et.has_trigger then
        return true
    end
    return false
end

local tech_is_disabled = function(tech)
    local env = get_env()
    local et = env[tech.name]
    if et and (et.hidden or not tech.enabled) then
        return true
    end
    return false
end

local tech_is_infinite = function(tech)
    local env = get_env()
    local et = env[tech.name]
    if et and et.is_infinite then
        return true
    end
    return false
end

local get_tech_without_prerequisites = function(force_index)
    -- -- Get Storage Force and sfName
    -- local ssf = get_force(force_index)
    -- local ssft = ssf.technology

    -- local tech = {}
    -- for t, prop in pairs(ssft) do
    --     if not prop.has_prerequisites then
    --         table.insert(tech, t)
    --     end
    -- end
    -- return tech
    local f = game.forces[force_index]
    local arr = {}
    for t, tech in pairs(f.technologies or {}) do
        if not tech.prerequisites then
            table.insert(arr, t)
        end
    end
    return arr
end

local get_entry_technologies = function(force_index)
    -- Get Storage Force and sfName
    -- local ssf = get_force(force_index)
    -- local ssft = ssf.technology

    -- local entry = {}
    -- for t, prop in pairs(ssft) do
    --     if prop.available and not prop.technology.researched then
    --         table.insert(entry, t)
    --     end
    -- end
    -- return entry

    local f = game.forces[force_index]
    local arr = {}
    for _, tech in pairs(f.technologies) do
        if tech_is_available(tech) then
            table.insert(arr, tech.name)
        end
    end
    return arr
end

local get_unresearched_blocking_technologies = function(force_index)
    local env = get_env()
    local f = game.forces[force_index]
    local arr = {}

    for _, tech in pairs(f.technologies) do
        local et = env[tech.name]
        if et and et.is_blocking and not tech.researched then
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

local remove_researched = function(force_index, prop)
    local f = game.forces[force_index]
    local to_remove, remove_count, total_count
    to_remove = {}
    remove_count, total_count = 0, 0
    for pre, _ in pairs(prop) do
        local tech = f.technologies[pre]
        if tech.researched then
            table.insert(to_remove, pre)
        end
    end
    if remove_count == total_count then
        prop = nil
    else
        for _, rem in pairs(to_remove) do
            prop[rem] = nil
        end
    end
end

local get_tech_meta = function(force_index)
    local f = game.forces[force_index]
    local env = get_env()

    -- Get all queued tech and queued prerequisites
    local queue = get_simple_queue(force_index)
    local queued_prerequisites = {}
    for _, q in pairs(queue or {}) do
        queued_prerequisites[q] = true
        if not env[q] then
            goto continue
        end
        for pre, _ in pairs(env[q].all_prerequisites or {}) do
            queued_prerequisites[pre] = true
        end
        ::continue::
    end

    -- Get all blocking/disabled tech
    local blocking_tech = get_unresearched_blocking_technologies(force_index)
    local disabled_tech = get_unresearched_disabled_technologies(force_index)

    local arr = {}
    for name, tech in pairs(f.technologies) do
        local et = env[tech.name]
        arr[name] = {
            is_researched = tech.researched,
            is_blocking = et.has_trigger,
            is_avalable = tech_is_available(tech),
            is_disabled = et.hidden or not tech.enabled,
            is_infinite = et.is_infinite,
            is_inherited = (queued_prerequisites[name] and not tech.researched),
            all_prerequisites = util.deepcopy(et.all_prerequisites), -- TODO figure out if deepcopy is necessary
            blocking_prerequisites = util.deepcopy(et.blocking_prerequisites), -- TODO figure out if deepcopy is necessary
            sciences = util.deepcopy(et.sciences)
        }

        -- Remove researched (blocking) prerequisites
        remove_researched(arr.all_prerequisites)
        remove_researched(arr.blocking_prerequisites)
    end
    return arr
end

stech.get_technology = function(force_index, technology_name)
    -- Get Storage Force and sfName
    local ssf = get_force(force_index)
    local ssft = ssf.technology
    local ssftn = ssft[technology_name]
    return ssftn
end

-- stech.get_unresearched_technologies_ordered = function(force_index)
--     -- Get Storage Force and sfName
--     local ssf = get_force(force_index)
--     local ssft = ssf.technology

--     -- Get entry tech
--     local entry_tech = get_entry_technologies(force_index)
--     local start_tech = get_tech_without_prerequisites(force_index)

--     local techlist, queue, visited, omit = {}, {}, {}, {}

--     for _, t in pairs(entry_tech) do
--         table.insert(queue, t)
--     end
--     for _, t in pairs(start_tech) do
--         table.insert(queue, t)
--     end

--     -- for _, t in pairs(entry_tech) do
--     --     table.insert(queue, t)
--     --     for s, _ in pairs(ssft[t].successors or {}) do
--     --         for p, _ in pairs(ssft[s].prerequisites) do
--     --             if not util.array_has_value(entry_tech, p) then
--     --                 omit[p] = true
--     --             end
--     --         end
--     --     end
--     -- end

--     while #queue > 0 do
--         -- Get the first next unvisited tech from the queue
--         local tech = table.remove(queue, 1)
--         if visited[tech] then
--             goto continue
--         end

--         -- Add the tech toour final array if it is not yet researched
--         local t = ssft[tech]
--         if not t.technology.researched then
--             table.insert(techlist, tech)
--         end
--         visited[tech] = true

--         -- Propagate properties to each successor
--         for suc, _ in pairs(t.successors or {}) do
--             local ts = ssft[suc]

--             -- Check if we can visit this successor next
--             local suitable = true
--             for tp, _ in pairs(ts.prerequisites or {}) do
--                 local pre = ssft[tp]
--                 suitable = suitable and (visited[tp] or omit[tp])
--             end
--             if suitable then
--                 table.insert(queue, suc)
--             else
--             end
--         end

--         ::continue::
--     end

--     return techlist
-- end

stech.get_unresearched_technologies_ordered = function(force_index)
    -- Get Storage Force and sfName
    -- local ssf = get_force(force_index)
    -- local ssft = ssf.technology
    local f = game.forces[force_index]

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
        local tn = table.remove(queue, 1)
        if visited[tn] then
            goto continue
        end

        -- Add the tech toour final array if it is not yet researched
        local tech = f.technologies[tn]
        if not tech.researched then
            table.insert(techlist, tn)
        end
        visited[tn] = true

        -- Propagate properties to each successor
        for _, suc in pairs(tech.successors or {}) do
            -- local ts = ssft[suc]

            -- Check if we can visit this successor next
            local suitable = true
            for tp, _ in pairs(suc.prerequisites or {}) do
                -- local pre = ssft[tp]
                suitable = suitable and (visited[tp] or omit[tp])
            end
            if suitable then
                table.insert(queue, suc.name)
                game.print("Added " .. suc.name)
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

-- stech.get_filtered_technologies_player = function(player_index, filter)
--     -- Get Storage Force and sfName
--     local p = game.get_player(player_index)
--     local f = p.force
--     local ssf = get_force(f.index)
--     local ssft = ssf.technology

--     local techlist = stech.get_unresearched_technologies_ordered(f.index)
--     local filtered_tech = {}
--     game.print(serpent.line(techlist))

--     for _, tech in pairs(techlist) do
--         local ssftt = ssft[tech]
--         if not filter then
--             goto skip_filter
--         end

--         -- Filter 0: Search text (do this one first because it will filter out the most sciences)
--         if filter.search_text and filter.search_text ~= "" and not tech_matches_search_text(player_index, tech) then
--             goto continue
--         end

--         -- Filter 1: Matches required sciences (do this one second because it will filter out a lot of sciences)
--         if #filter.allowed_sciences > 0 and
--             not util.array_has_all_values(filter.allowed_sciences, (ssftt.sciences or {})) then
--             goto continue
--         end

--         -- Filter 2: Disabled/hidden tech
--         if filter.hide_tech["disabled_tech"] and (not ssftt.technology.enabled or ssftt.hidden) then
--             goto continue
--         end

--         -- Filter 3: Manual trigger tech
--         if filter.hide_tech["manual_trigger_tech"] and ssftt.has_trigger then
--             goto continue
--         end

--         -- Filter 4: Infinite tech
--         if filter.hide_tech["infinite_tech"] and ssftt.is_infinite then
--             goto continue
--         end

--         -- Filter 5: Inherited tech
--         if filter.hide_tech["inherited_tech"] and (ssftt.inherited_by ~= nil or ssftt.queued) then
--             goto continue
--         end

--         -- Filter 6: Unavailable successors
--         if filter.hide_tech["unavailable_successors"] and (ssftt.blocked_by ~= nil or ssftt.disabled_by ~= nil) then
--             goto continue
--         end

--         -- Filter 7: Show category
--         if filter.show_tech ~= "all" then
--             if filter.show_tech == "essential" then
--                 if not ssftt.essential then
--                     goto continue
--                 end
--             else
--                 -- Check if any of this category's prototypes or effects match any of the given tech's prototypes or effects
--                 for type, prop in pairs(const.categories[filter.show_tech]) do
--                     if ssftt[type] then
--                         for _, p in pairs(prop) do
--                             if ssftt[type][p] then
--                                 -- There is a match, no need to look further
--                                 goto skip_filter
--                             end
--                         end
--                     end
--                 end
--                 goto continue
--             end
--         end

--         ::skip_filter::
--         -- If we passed all the filters, add the science to our return array
--         table.insert(filtered_tech, tech)

--         ::continue::
--     end

--     return filtered_tech

-- end

stech.get_filtered_technologies_player = function(player_index, filter)
    -- Get Storage Force and sfName
    local p = game.get_player(player_index)
    local f = p.force
    local meta = get_tech_meta(f.index)
    local env = get_env()
    -- local ssf = get_force(f.index)
    -- local ssft = ssf.technology

    local techlist = stech.get_unresearched_technologies_ordered(f.index)
    local filtered_tech = {}

    for _, tech in pairs(techlist) do
        -- local ssftt = ssft[tech]
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

--------------------------------------------------------------------------------
--- Update state
--------------------------------------------------------------------------------

local propagate_property = function(from, to, prop)
    if not to[prop] then
        to[prop] = {}
    end
    for k, v in pairs(from[prop] or {}) do
        to[prop][k] = v
    end
end

local cleanup_property = function(tech, prop)
    if tech[prop] then
        local active = true
        for k, v in pairs(tech[prop]) do
            active = active and v
            if not v then
                tech[prop][k] = nil
            end
        end
        if not active then
            tech[prop] = nil
        end
    end
end

local propagate_successors = function(force_index, entry_tech)
    -- Go through all successors (once) and inherit relevant marks of parent
    local ssf = get_force(force_index)
    local ssft = ssf.technology

    local queue, visited, omit = {}, {}, {}

    for _, t in pairs(entry_tech) do
        table.insert(queue, t)
        for s, _ in pairs(ssft[t].successors or {}) do
            for p, _ in pairs(ssft[s].prerequisites) do
                if not util.array_has_value(entry_tech, p) then
                    omit[p] = true
                end
            end
        end
    end

    local propagate_properties = {"blocked_by", "disabled_by", "blocked_prerequisites", "unblocked_prerequisites",
                                  "entry_nodes"}

    while #queue > 0 do
        -- Get the first next unvisited tech from the queue
        local tech = table.remove(queue, 1)
        if visited[tech] then
            goto continue
        end
        visited[tech] = true

        -- Propagate properties to each successor
        local t = ssft[tech]
        local is_blocking = (t.has_trigger and not t.technology.researched)
        local is_disabled = ((not t.technology.enabled or t.hidden) and not t.technology.researched)
        for suc, _ in pairs(t.successors or {}) do
            local ts = ssft[suc]

            -- Propagate all
            for _, pp in pairs(propagate_properties) do
                propagate_property(t, ts, pp)
            end

            -- Current tech as un-/blocked
            if t.technology.researched then
                for _, prop in pairs(propagate_properties) do
                    ts[prop][tech] = false
                end
                -- TODO: Decide if we need ts.researched_prerequisites
            else
                -- Trigger tech
                -- if is_blocking then
                ts.blocked_by[tech] = is_blocking
                -- end

                -- Disabled
                -- TODO: Keep in mind that enabled can be changed at runtime
                -- We need to catch this at a later point in time
                -- if is_disabled then
                ts.disabled_by[tech] = is_disabled
                -- end

                -- All prerequisites
                if not ts.all_prerequisites then
                    ts.all_prerequisites = {}
                end
                for k, v in pairs(t.all_prerequisites or {}) do
                    ts.all_prerequisites[k] = v
                end
                ts.all_prerequisites[tech] = true

                -- Mark as un-/blocked prerequisite
                if is_blocking or is_disabled then
                    -- There is at least one blocked tech, add this tech to the blocked tech list
                    ts.blocked_prerequisites[tech] = true
                    ts.unblocked_prerequisites[tech] = false
                else
                    ts.blocked_prerequisites[tech] = false
                    ts.unblocked_prerequisites[tech] = true
                end

                -- Mark as entry
                if t.available then
                    ts.entry_nodes[tech] = true
                else
                    ts.entry_nodes[tech] = false
                end

            end

            -- Check if we can visit this successor next
            local suitable = true
            for tp, _ in pairs(ts.prerequisites) do
                local pre = ssft[tp]
                suitable = suitable and (visited[tp] or omit[tp])
            end
            if suitable then
                table.insert(queue, suc)
                for _, pp in pairs(propagate_properties) do
                    -- cleanup_property(ts, pp)
                end
            end
        end

        ::continue::
    end

    -- Cleanup false properties for all visited tech
    for tech, _ in pairs(visited) do
        for _, pp in pairs(propagate_properties) do
            local has_prop = false
            -- Remove all tech marked false for each property and remember if any tech is true
            for k, v in pairs(ssft[tech][pp] or {}) do
                if v then
                    has_prop = true
                else
                    ssft[tech][pp][k] = nil
                end
            end
            -- Remove the property array if none are true
            if not has_prop then
                ssft[tech][pp] = nil
            end
        end
    end
end

local propagate_queued = function(force_index, technology_name, queued)
    local ssf = get_force(force_index)
    local ssft = ssf.technology
    local queue = {technology_name}
    local visited = {}

    while #queue > 0 do
        -- Get the first next unvisited tech from the queue
        local tech = table.remove(queue, 1)

        if visited[tech] then
            goto continue
        end
        visited[tech] = true

        local ssftn = ssft[tech]
        if not ssftn then
            goto continue
        end

        for pre, _ in pairs(ssftn.prerequisites or {}) do
            local ssftp = ssft[pre]
            if queued and not ssftp.technology.researched then
                if not ssftp.inherited_by then
                    ssftp.inherited_by = {}
                end
                ssftp.inherited_by[technology_name] = true
            else
                if ssftp.inherited_by then
                    ssftp.inherited_by[technology_name] = nil
                    if #ssftp.inherited_by == 0 then
                        ssftp.inherited_by = nil
                    end
                end
            end
            table.insert(queue, pre)
        end

        ::continue::
    end

    --     for pre, _ in pairs(ssftn.prerequisites or {}) do
    --         local ssftp = ssft[pre]
    --         if queued and not ssftp.technology.researched then
    --             if not ssftp.inherited_by then
    --                 ssftp.inherited_by = {}
    --             end
    --             ssftp.inherited_by[technology_name] = true
    --         else
    --             if ssftp.inherited_by then
    --                 ssftp.inherited_by[technology_name] = nil
    --                 if #ssftp.inherited_by == 0 then
    --                     ssftp.inherited_by = nil
    --                 end
    --             end
    --         end
    --         propagate_queued(force_index, technology_name, queued, pre)
    --     end
end

local init_technology = function(force_index, technology_name)
    -- Get some variables to work with
    local env = get_env()
    local ssf = get_force(force_index)
    local ssft = ssf.technology
    local ssftn = ssft[technology_name]
    local f = game.forces[force_index]
    local ft = f.technologies
    local ftt = ft[technology_name]
    local tn = technology_name

    -- Copy environment properties
    -- ssftn.hidden = env[tn].hidden
    -- ssftn.essential = env[tn].essential
    for k, v in pairs(env[tn]) do
        ssftn[k] = v
    end

    -- Copy actual tech status
    -- TODO: Maybe it is better to store a reference to the technology instead
    ssftn.technology = ftt
    ssftn.queued = util.array_has_value(get_simple_queue(force_index), technology_name)

    -- Check if the tech is available i.e. all prerequisites have been researched
    local available = true
    for pre, _ in pairs(env[tn].prerequisites or {}) do
        if ft[pre] then
            available = available and ft[pre].researched
        end
    end
    ssftn.available = available
end

stech.update_technology = function(force_index, technology_name)
    -- Get Storage Force and sfName
    local env = get_env()
    local ssf = get_force(force_index)
    local ssft = ssf.technology

    -- Get Force and fTechnology
    local f = game.forces[force_index]
    local ft = f.technologies

    -- Normalize technology name to array
    if type(technology_name) == "string" then
        technology_name = {technology_name}
    end

    -- Make array of to be updated tech
    local to_update = {}

    for _, tech_name in pairs(technology_name or {}) do

        local ssftn = ssft[tech_name]
        if not ssftn then
            goto continue
        end

        if not ft or not ft[tech_name] then
            goto continue
        end
        local ftn = f.technologies[tech_name]

        table.insert(to_update, tech_name)
        for suc, _ in pairs(ssftn.successors or {}) do
            table.insert(to_update, suc)
        end
        ::continue::
    end

    -- Update each tech
    for _, u in pairs(to_update) do
        -- Update properties
        init_technology(f.index, u)
    end

    -- Propagate queued property for current tech
    for _, tech_name in pairs(technology_name) do
        local ssftn = ssft[tech_name]
        propagate_queued(force_index, technology_name, ssftn.queued)
    end

    -- Propagate properties to successors of all affected tech
    propagate_successors(force_index, to_update)
end

stech.update_technology_queued = function(force_index, technology_name)
    -- This function updates only the queued/inherited properties

    -- Get some variables to work with
    local ssf = get_force(force_index)
    local ssft = ssf.technology
    local ssftn = ssft[technology_name]
    if not ssftn then
        return
    end

    -- Copy/propagate actual queued status
    ssftn.queued = util.array_has_value(get_simple_queue(force_index), technology_name)
    propagate_queued(force_index, technology_name, ssftn.queued)
end

stech.update_pending_technology = function(force_index)
    local ssf = get_force(force_index)
    if not ssf then
        return
    end
    stech.update_technology(force_index, ssf.to_update)
    ssf.to_update = {}
end

stech.request_technology_update = function(force_index, tech_name)
    local ssf = get_force(force_index)
    if not ssf then
        return
    end
    for _, u in pairs(ssf.to_update or {}) do
        if u == tech_name then
            return
        end
    end
    table.insert(ssf.to_update, tech_name)
end
stech.technology_needs_update = function(force_index)
    local ssf = get_force(force_index)
    return (ssf.to_update and #ssf.to_update > 0)
end

--------------------------------------------------------------------------------
--- Init
--------------------------------------------------------------------------------

stech.init_force = function(force_index)
    -- Make sure to call this function after init_env
    -- Get Storage State Force and ssfTechnology
    local env = get_env()
    local ssf = get_force(force_index)
    ssf.technology = {}
    local ssft = ssf.technology

    -- Init to update array
    if not ssf.to_update then
        ssf.to_update = {}
    end

    -- Get Force and fTechnology
    local f = game.forces[force_index]
    local ft = f.technologies
    if not ft then
        return
    end

    -- Make initial array by copying default environment tech
    for t, prop in pairs(env) do
        ssft[t] = util.deepcopy(prop)
    end

    -- Populate force specific tech array
    local queue, entry = {}, {}
    for t, _ in pairs(ft) do
        -- Update the tech
        init_technology(force_index, t)

        -- Remember entry tech and queued tech
        if ssft[t].available then
            table.insert(entry, t)
        end
        if ssft[t].queued then
            table.insert(queue, t)
        end
    end

    -- Propagate queued tech
    for _, q in pairs(queue) do
        propagate_queued(force_index, q, true)
    end

    -- Propagate properties to successors
    propagate_successors(force_index, entry)

    -- FOR DEBUGGING
    -- for _, p in pairs(game.players) do
    --     if p.force.index == force_index then
    --         log("===== Tech array =====")
    --         log(serpent.block(ssft))
    --     end
    -- end

end

stech.init = function()
    for _, f in pairs(game.forces) do
        stech.init_force(f.index)
    end
end

return stech
