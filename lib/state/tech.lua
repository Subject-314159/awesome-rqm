local const = require("lib.const")
local util = require("lib.util")
local translate = require("lib.state.translate")

-- This module is only to be required in state and to be treated as an extension
local stech = {}

--------------------------------------------------------------------------------
--- Generic
--------------------------------------------------------------------------------

-- Data model
-- local storage.state.env[TECHNOLOGY_PROPERTIES] = {
--     [tech_name] = {
--         -- From prototype
--         has_trigger = bool
--         is_infinite = bool
--         sciences = {"science-name", ...}
--         all_prerequisites = {[tech_name] = bool, ...}
--         blocking_prerequisites = {[tech_name] = bool, ...}
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
    return storage.state.tech.env
end
local set_env = function(env)
    storage.state.tech.env = env
end
local get_queue = function(force_index)
    -- if not storage or not storage.state or not storage.state.forces or not storage.state.forces[force_index] or not storage.state.forces[force_index].queued then
    --     return {}
    -- else
        return storage.state.tech.forces[force_index].queued
    -- end
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

local init_env = function()
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

        -- Init queue variable for BFS
        local queue

        -- Get first line successors
        queue = {}
        tn.has_successors = false
        for s, _ in pairs(t.successors) do
            tn.has_successors = true
            table.insert(queue, s)
        end

        -- Get all successors
        tn.all_successors = {}
        while #queue > 0 do
            -- Get first next unvisited tech
            local tech = table.remove(queue, 1)
            if tn.all_successors[tech] then
                goto continue
            end
            local prot = prototypes.technology[tech]

            -- Mark current tech visited
            tn.all_successors[tech] = true

            -- Add all unvisited predecessors of current tech to the queue
            for s, _ in pairs(prot.prerequisites or {}) do
                if not tn.all_successors[s] then
                    table.insert(queue, s)
                end
            end

            ::continue::
        end

        -- Get first line prerequisites
        queue = {}
        tn.has_prerequisites = false
        for p, _ in pairs(t.prerequisites) do
            tn.has_prerequisites = true
            table.insert(queue, p)
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
    set_env(tech_env)
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

local tech_is_disabled = function(tech)
    local env = get_env()
    local et = env[tech.name]
    if et and (et.hidden or not tech.enabled) then
        return true
    end
    return false
end

local get_tech_without_prerequisites = function(force_index)
    local f = game.forces[force_index]
    local arr = {}
    for t, tech in pairs(f.technologies or {}) do
        if not tech.prerequisites then
            -- table.insert(arr, t)
            arr[tech.name] = true
        end
    end
    return arr
end

local get_entry_technologies = function(force_index)
    local f = game.forces[force_index]
    local arr = {}
    for _, tech in pairs(f.technologies) do
        if tech_is_available(tech) then
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

stech.get_tech_meta = function(force_index)
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
            is_researched = tech.researched,
            is_blocking = et.has_trigger,
            is_avalable = tech_is_available(tech),
            is_disabled = et.hidden or not tech.enabled,
            is_infinite = et.is_infinite,
            is_inherited = (all_queued_inherited[name] and not tech.researched),
            is_essential = et.essential,
            is_unavailable_successor = false, -- To be updated dynamically
            all_prerequisites = util.deepcopy(et.all_prerequisites), -- TODO figure out if deepcopy is necessary
            -- blocking_prerequisites = util.deepcopy(et.blocking_prerequisites), -- TODO figure out if deepcopy is necessary // figure out if this is arry necessary
            sciences = et.sciences,
            blocked_by = {},
            disabled_by = {}
        }

        -- Remove researched (blocking) prerequisites
        remove_researched(arr.all_prerequisites)
        -- remove_researched(arr.blocking_prerequisites)

        -- Check if this is an unavailable successor
        for p,_ in pairs et.all_prerequisites) do
            if all_trigger_tech[p] then et.blocked_by[p] = true is_unavailable_successor = true end
            if all_disabled_tech[p] then et.disabled_by[p] = true is_unavailable_successor = true end
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
    for _, t in pairs(start_tech) do
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

stech.get_filtered_technologies_player = function(player_index, filter)
    -- Get Storage Force and sfName
    local p = game.get_player(player_index)
    local f = p.force
    local meta = stech.get_tech_meta(f.index)
    local env = get_env()

    local techlist = get_unresearched_technologies_ordered(f.index)
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
        table.insert(filtered_tech, tech)

        ::continue::
    end

    return filtered_tech

end

--------------------------------------------------------------------------------
--- Update state
--------------------------------------------------------------------------------

stech.register_queued = function(force_index, tech_name)
    local stf = storage.tech.forces[force_index]
    sft.queued[tech_name] = true
end
stech.deregister_queued = function(force_index, tech_name)
    sft.queued[tech_name] = nil
end

--------------------------------------------------------------------------------
--- Init
--------------------------------------------------------------------------------

stech.init_force = function(force_index)
    -- Make sure to call this function after init_env
    -- Get Storage State Force and ssfTechnology
    -- local env = get_env()

    --Init force array
    if not storage.tech.forces[force_index] then storage.tech.forces[force_index] = {} end
    local stf = storage.tech.forces[force_index]
    if not stf.queued then stf.queued = {} end

    -- FOR DEBUGGING
    -- for _, p in pairs(game.players) do
    --     if p.force.index == force_index then
    --         log("===== Tech array =====")
    --         log(serpent.block(ssft))
    --     end
    -- end

end

stech.init = function()
    local ss = storage.state
    if not ss then return end
    if not ss.tech then ss.tech = {} end
    if not ss.tech.forces then ss.tech.forces = {} end
    
    init_env()
    for _, f in pairs(game.forces) do
        stech.init_force(f.index)
    end
end

return stech
