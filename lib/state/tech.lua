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
--         -- From runtime
--         technology = LuaTechnology
--         enabled = bool
--         hidden = bool
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
            if pt == proto.type then return proto.type end
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
    local prototypes = {}
    local items = {}

    -- Get the items from the recipe
    if has_recipe[effect.type] then
        local r = prototypes.recipe[effect.recipe]
        for _, p in pairs(r.products) do
            if p.type == "item" then
                table.insert(items,p.name)
            end
        end
    end

    -- Get the item
    if has_items[effect.type] then
        table.insert(items,effect.item)
    end

    -- Search for the actual prototypes based on the items
    if #items > 0 then
        for _, itm in pairs(items) do
            -- Get the item prototype
            local ip = prototypes.item[itm]
            local proto = get_allowed_prototype(ip)
            if proto then table.insert(prototypes,proto) end

            -- Get the prototype of the place result
            if itm.place_result then
                local ipr = prototypes.entity[itm.place_result]
                proto = get_allowed_prototype(ipr)
                if proto then table.insert(prototypes,proto) end
            end
        end
    end

    -- Return the array with all prototypes associated with this effect
    return prototypes
end

stech.init_env = function()

    -- Store array of tech pre-/successors and blocking types
    local tech = {}
    for name, t in pairs(prototypes.technology) do
        -- Init/get the empty tech array
        if not tech[name] then
            tech[name] = {}
        end
        local tn = tech[name]

        -- Copy standard properties
        tn.enabled = t.enabled
        tn.has_trigger = (t.research_trigger ~= nil)
        tn.research_trigger = t.research_trigger
        tn.is_infinite = t.max_level >= 4294960000
        tn.essential = t.essential
        tn.order = t.order

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
        for s, _ in pairs(t.prerequisites) do
            tn.prerequisites[s] = true
            tn.has_prerequisites = true
        end
    end

    -- Store the technology properties in environment
    storage.state.env[TECHNOLOGY_PROPERTIES] = tech
end

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
        if prop.available and not prop.researched then
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
        if not t.researched then
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

stech.get_filtered_technologies_player = function(player_index, filter)
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
        if filter.hide_tech["disabled_tech"] and (not ssftt.enabled or ssftt.hidden) then
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
        local is_blocking = (t.has_trigger and not t.researched)
        local is_disabled = ((not t.enabled or t.hidden) and not t.researched)
        for suc, _ in pairs(t.successors or {}) do
            local ts = ssft[suc]

            -- Propagate all
            for _, pp in pairs(propagate_properties) do
                propagate_property(t, ts, pp)
            end

            -- Current tech as un-/blocked
            if t.researched then
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

local propagate_queued
propagate_queued = function(force_index, technology_name, queued, cur)
    -- This function is to be called when we alter the modqueue
    -- Go through all prerequisites (once) and set the queued mark accordingly
    if not cur then
        cur = technology_name
    end
    local ssf = get_force(force_index)
    local ssft = ssf.technology
    local ssftn = ssft[cur]

    for pre, _ in pairs(ssftn.prerequisites or {}) do
        local ssftp = ssft[pre]
        if queued and not ssftp.researched then
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
        propagate_queued(force_index, technology_name, queued, pre)
    end
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
    ssftn.technology = ftt -- TODO validate if we make a reference to the actual tech
    ssftn.enabled = ftt.enabled
    ssftn.researched = ftt.researched
    ssftn.queued = util.array_has_value(get_simple_queue(force_index), technology_name)

    -- Check if the tech is available i.e. all prerequisites have been researched
    local available = true
    for pre, _ in pairs(env[tn].prerequisites or {}) do
        available = available and ft[pre].researched
    end
    ssftn.available = available
end

stech.update_technology = function(force_index, technology_name)
    -- Get Storage Force and sfName
    local env = get_env()
    local ssf = get_force(force_index)
    local ssft = ssf.technology
    local ssftn = ssft[technology_name]
    if not ssftn then
        return
    end

    -- Get Force and fTechnology
    local f = game.forces[force_index]
    local ft = f.technologies
    if not ft or not ft[technology_name] then
        return
    end
    local ftn = f.technologies[technology_name]

    -- Make array of to be updated tech
    local to_update = {technology_name}
    -- for suc, _ in pairs(env[technology_name].successors or {}) do
    --     table.insert(to_update, suc)
    -- end
    for suc, _ in pairs(ssftn.successors or {}) do
        table.insert(to_update, suc)
    end

    -- Update each tech
    for _, u in pairs(to_update) do
        -- Update properties
        init_technology(f.index, u)
    end

    -- Propagate queued property for current tech
    propagate_queued(force_index, technology_name, ssftn.queued)

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
