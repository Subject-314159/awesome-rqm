local analyzer = {}

local const = require('lib.const')
local util = require('lib.util')
local state = require('lib.state')

local get_all_queued_tech = function(force)

    local all = {}
    -- local gfq = storage.forces[force.index].queue
    -- for _, q in pairs(gfq or {}) do
    --     table.insert(all, q.technology_name)
    --     for _, t in pairs(q.metadata.new_blocked or {}) do
    --         table.insert(all, t)
    --     end
    --     for _, t in pairs(q.metadata.new_unblocked or {}) do
    --         table.insert(all, t)
    --     end
    -- end
    return all
end

local get_tech_blocked_marks = function(owner, tech, filter)
    if not filter then
        return
    end

    -- Normalize owner
    local p, f, owner_is_player
    if owner.object_name == "LuaForce" then
        f = owner
        owner_is_player = false
    else
        p = owner
        f = p.force
        owner_is_player = true
    end
    local technology = f.technologies[tech]

    -- The initial array
    local marks = {}

    -- Check 1: The technology contains only our allowed sciences
    local sci = {}
    for _, ing in pairs(technology.research_unit_ingredients) do
        table.insert(sci, ing.name)
    end
    if filter.allowed_sciences ~= nil and not util.array_has_all_values(filter.allowed_sciences, sci) then
        table.insert(marks, "tech_does_not_match_allowed_science")
    end

    -- Check 2: The technology is disabled/hidden
    if filter.hide_categories.disabled_tech and
        (not technology.enabled or prototypes.technology[technology.name].hidden) then
        table.insert(marks, "tech_is_not_enabled")
    end

    -- Check 3: The technology is unlocked by manual trigger
    if filter.hide_categories.manual_trigger_tech and prototypes.technology[technology.name].research_trigger ~= nil then
        table.insert(marks, "tech_is_manual_trigger")
    end

    -- Check 4: The technology is infinite
    if filter.hide_categories.infinite_tech and technology.research_unit_count_formula ~= nil then
        table.insert(marks, "tech_is_infinite")
    end

    -- Check 4: The technology is blacklisted
    -- TODO

    -- Check 5: The technology is already queued
    if filter.hide_categories.inherited_tech then
        local queued = get_all_queued_tech(p.force)
        if util.array_has_value(queued, technology.name) then
            table.insert(marks, "tech_is_inherited")
        end
    end

    -- Return the marks or nil if empty
    if next(marks) == nil then
        return nil
    else
        return marks
    end
end

local get_filter = function(owner)
    -- Normalize owner
    local p, f, owner_is_player
    if owner.object_name == "LuaForce" then
        f = owner
        owner_is_player = false
    else
        p = owner
        f = p.force
        owner_is_player = true
    end

    local sciences = state.get_environment_setting("available_sciences")
    -- Build the filter
    local filter
    if owner_is_player then
        -- Get allowed sciences
        local allowed = {}
        for _, s in pairs(sciences or {}) do
            if state.get_player_setting(p.index, "allowed_" .. s) then
                table.insert(allowed, s)
            end
        end
        if next(allowed) == nil then
            allowed = sciences
        end

        -- Get hide categories
        local hide = {}
        for k, v in pairs(const.default_settings.player.hide_tech) do
            local state = state.get_player_setting(p.index, k, v)
            if state then
                hide[k] = true
            end
        end
        filter = {
            allowed_sciences = allowed,
            hide_categories = hide,
            show_categories = {}
        }
    else
        -- TODO: Build filter based on force settings
        -- game.print("[RQM] ERROR: Unable to build filter for force, please open a bug report on the mod portal")
        local hide = {}
        for k, v in pairs(const.default_settings.force.queue_blocking_tech) do
            hide[k] = true
        end
        filter = {
            hide_categories = hide,
            show_categories = {}
        }
    end

    return filter
end

local tech_is_not_trigger = function(technology)
    -- Check if the technology is blocked according to our rules

    -- Rule 1: The technology requires a trigger to unblock
    -- Get the prototype from the technology and check if a research_trigger exists
    local p = prototypes.technology[technology.name]
    if p.research_trigger ~= nil then
        return true
    end
end

-- DFS from an entry node through all allowed techs (from previous flatlist) and get all blocked tech and their successors
-- BACKLOG: Convert to BFS if necessary?
analyzer.get_downsteam_blocked_tech_flat = function(force, tech_name, allowed, visited, blocked, predecessor_is_blocked)
    -- Is_blocked is to be passed by value instead of by reference because we are only interested in the downstream value
    local is_blocked = predecessor_is_blocked or false

    -- Early exit if we already visited this node
    -- If we came from a blocked technology, we should check the blocked array (we visited this tech from another blocked path)
    -- If not we need to check the visited array
    if is_blocked then
        if blocked[tech_name] then
            return
        end
    else
        if visited[tech_name] then
            return
        end
    end

    -- Add tech to visited array
    visited[tech_name] = true

    -- Get the technology class from the name
    local technology = force.technologies[tech_name]

    -- Check if the technology is blocked
    -- Either because of our rules, or because a prior tech was blocked and we passed the flagg
    if tech_is_not_trigger(technology) or is_blocked then
        -- Add tech to the blocked tech list
        blocked[tech_name] = true
        -- Set is blocked flag
        is_blocked = true
    end

    -- Loop through the successors
    for n, p in pairs(technology.successors or {}) do
        -- Only if the successor is in the allow list
        -- If we reached the destination technology then none of the successors will be on the allow list, so no action will be performed
        if allowed[p.name] then
            -- TODO: Why is this empty?
            analyzer.get_downsteam_blocked_tech_flat(force, p.name, allowed, visited, blocked, is_blocked)
        end
    end
end

analyzer.get_downsteam_tech = function(owner, input_tech_names, target_tech_names, blocked_tech_categories,
    allowed_tech_names)
    local visited = {}
    local queue = {}
    local mark_map = {}
    local mark_inherit = {}
    local found_targets = {}
    local allowed_set = {}
    local blocked_set = {}
    local blacklist_set = {}

    -- Normalize owner to force
    local p, f
    if owner.object_name == "LuaForce" then
        f = owner
    else
        p = owner
        f = p.force
    end
    local technologies = f.technologies

    -- Convert allowed_tech_names and blocked_tech_categories to dictionary for quick lookup
    if allowed_tech_names then
        for k, v in pairs(allowed_tech_names) do
            if type(v) == "boolean" then
                allowed_set[k] = v
            else
                allowed_set[v] = true
            end
        end
    end
    if blocked_tech_categories then
        for _, tech in pairs(blocked_tech_categories) do
            blocked_set[tech] = true
        end
    end

    -- Normalize tech names to array
    if type(target_tech_names) == "string" then
        target_tech_names = {target_tech_names}
    end

    -- Get the filter
    local filter = get_filter(owner)

    -- Initialize queue with input techs
    for _, tech in pairs(input_tech_names) do
        table.insert(queue, tech)
    end

    -- Main loop (dynamic)
    while #queue > 0 do
        -- Get the first next tech from the queue
        local tech = table.remove(queue, 1)
        if visited[tech] then
            goto continue
        end
        visited[tech] = true

        -- Check if current tech is marked
        local marks = get_tech_blocked_marks(owner, tech, filter)
        if marks then
            for _, mark in pairs(marks) do
                -- TODO: Validate that we need to stop here if we have a blocked tech array but not a target tech array;
                -- because if we are going to traverse the whole tech tree every time it might cost valuable UPS
                -- Currently we do not use this subfunction yet
                if blocked_tech_categories and util.array_has_value(blocked_tech_categories, mark) then
                    -- Remove the tech from the visited array
                    visited[tech] = nil
                    -- Remove the successors from further processing
                    for _, suc in pairs(technologies[tech].successors) do
                        blacklist_set[suc.name] = true
                    end

                    goto continue -- It might be that we crash here because we do an illegal jump
                end

                -- Mark the tech
                if not mark_map[mark] then
                    mark_map[mark] = {}
                end
                mark_map[mark][tech] = true
            end
        end

        -- Inherit predecessor marks
        for _, pre in pairs(technologies[tech].prerequisites) do
            -- Inherit from marked
            for n, mm in pairs(mark_map) do
                -- Check if this mark is allowed to be propagated (i.e. not in the no_propagate_settings array)
                -- and if we should hide unavailable successors
                if not util.array_has_value(const.no_propagate_settings.player.hide_tech, n) and
                    filter.hide_categories.unavailable_successors then
                    if mm[pre.name] then
                        mm[tech] = true

                        if not mark_inherit[n] then
                            mark_inherit[n] = {}
                        end
                        mark_inherit[n][tech] = true
                    end
                end
            end

            -- Inherit from inherited
            for n, mm in pairs(mark_inherit) do
                if not util.array_has_value(const.no_propagate_settings.player.hide_tech, n) and
                    filter.hide_categories.unavailable_successors then
                    if mm[pre.name] then
                        mm[tech] = true
                    end
                end
            end
        end

        -- Check if current tech is a target tech
        if target_tech_names and util.array_has_value(target_tech_names, tech) then
            table.insert(found_targets, tech)
            if #found_targets == #target_tech_names then
                break
            end
            -- TODO: Validate if we can compare the array length this way

            -- found_targets[tech] = true
            -- -- Stop if all targets found
            -- if all_targets_found(target_tech_names, found_targets) then
            --     break
            -- end
        end

        -- Process successors
        for _, suc in pairs(technologies[tech].successors) do
            -- Skip this successor if blacklisted
            if blacklist_set[suc.name] then
                goto skip_suc
            end

            -- Skip this successor if not all predecessors are visited
            for _, pre in pairs(suc.prerequisites) do
                if not visited[pre.name] and not pre.researched then
                    goto skip_suc
                end
            end

            -- Skip this successor if it is not in the allow list
            if allowed_tech_names and not allowed_set[suc.name] then
                goto skip_suc
            end

            -- If we got here we can safely add the successor to the queue
            table.insert(queue, suc.name)
            ::skip_suc::
        end

        ::continue::
    end

    -- Inverse the mark map based on the visited tech and create the final return table
    local res = {}
    for k, v in pairs(visited) do
        local marks, inherit = {}, {}
        for mark, prop in pairs(mark_map) do
            if prop[k] then
                table.insert(marks, mark)
            end
        end
        for mark, prop in pairs(mark_inherit) do
            if prop[k] then
                table.insert(inherit, mark)
            end
        end
        local t = f.technologies[k]
        local prop = {
            technology = t,
            tech_name = t.name,
            visited = true,
            is_entry = util.array_has_value(input_tech_names, t.name),
            is_blocked = next(inherit) ~= nil,
            blocked_reasons = inherit,
            is_blocking = next(marks) ~= nil,
            is_blocking_reasons = marks
        }
        res[k] = prop
    end

    return res
end

-- Reverse DFS from target technology to every entry node
analyzer.get_upstream_tech_flat = function(force, technology, visited, entry)
    -- Early exit if we already visited this node, or if this tech is not enabled
    -- if visited[technology.name] or not technology.enabled then
    if visited[technology.name] then
        return
    end

    -- Add tech to visited array
    visited[technology.name] = true

    -- If we can research this technology it is an entry node, else we need to DFS prerequisite unresearched technologies
    -- Check if all prerequisites of this tech are researched
    local is_entry = true
    for _, p in pairs(technology.prerequisites or {}) do
        if not p.researched then
            is_entry = false
            break
        end
    end
    -- If it is an entry point, add it to the array
    -- If not, search deeper
    if is_entry then
        table.insert(entry, technology.name)
    else
        for _, p in pairs(technology.prerequisites or {}) do
            if not p.researched then
                analyzer.get_upstream_tech_flat(force, p, visited, entry)
            end
        end
    end
end

local get_all_entry_tech = function(owner)
    -- Normalize owner to force
    local p, f
    if owner.object_name == "LuaForce" then
        f = owner
    else
        p = owner
        f = p.force
    end

    -- Loop through all tech in this force
    local arr = {}
    for k, v in pairs(f.technologies) do
        -- Check if current tech is enabled but not yet researched
        if v.enabled and not v.researched then
            -- Check if all predecessors are researched
            local is_available = true
            for _, t in pairs(v.prerequisites or {}) do
                -- If one of the predecessors is not researched the current tech is not available
                if not t.researched then
                    is_available = false
                    break
                end
            end

            -- Add the current tech as entry tech
            if is_available then
                table.insert(arr, v.name)
            end
        end
    end

    -- Return the result
    return arr
end

analyzer.get_filtered_tech_player = function(player_index)
    local p = game.get_player(player_index)
    local f = p.force

    local entry_tech = get_all_entry_tech(f)
    local res = analyzer.get_downsteam_tech(p, entry_tech)

    -- For now, only return tech that is not blocked
    -- TODO: When we want to display additional info in the available tech field, we need to return additional info from here
    local arr = {}
    for k, v in pairs(res) do
        if not v.is_blocked and not v.is_blocking then
            table.insert(arr, v.technology)
        end
    end
    return arr
end

analyzer.get_single_tech_force = function(force_index, tech_name)
    local f = game.forces[force_index]
    local t = f.technologies[tech_name]
    if not t then
        return
    end

    -- local entry_tech = get_all_entry_tech(f)
    local visited, entry = {}, {}
    analyzer.get_upstream_tech_flat(f, t, visited, entry)
    local res = analyzer.get_downsteam_tech(f, entry, tech_name, nil, visited)
    return res
end

analyzer.tech_matches_search_text = function(player_index, tech)
    local p = game.get_player(player_index)
    local f = p.force
    local technology = f.technologies[tech]

    -- Get the search text (or return true if no search)
    local needle = state.get_player_setting(player_index, "search_text")
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

return analyzer
