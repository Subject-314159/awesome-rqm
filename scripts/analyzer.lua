local analyzer = {}

local util = require('util')
local state = require('state')

local get_tech_blocked_marks = function(owner, tech)
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

    -- Build the filter
    local filter
    if owner_is_player then
        -- Get allowed sciences
        local sciences = state.get_environment_setting("available_sciences")
        local allowed = {}
        for _, s in pairs(sciences) do
            if state.get_player_setting(p.index, "allowed_" .. s) then
                table.insert(allowed, s)
            end
        end
        if next(allowed) == nil then
            allowed = sciences
        end
        filter = {
            allowed_sciences = allowed,
            hide_categories = {},
            show_categories = {}
        }
    else
        -- TODO: Build filter based on force settings
        game.print("[RQM] Error: Unable to build filter for force")
    end

    -- The initial array
    local marks = {}

    -- Check 0: The technology is enabled
    if not technology.enabled then
        table.insert(marks, "tech_is_not_enabled")
    end

    -- Check 1: The technology contains only our allowed sciences
    local sci = {}
    for _, ing in pairs(technology.research_unit_ingredients) do
        table.insert(sci, ing.name)
    end
    if filter.allowed_sciences ~= nil and not util.array_has_all_values(filter.allowed_sciences, sci) then
        -- game.print('Does not match science')
        table.insert(marks, "tech_does_not_match_allowed_science")
    end

    -- Check 2: The technology is not hidden
    -- TBD

    -- Check 3: The technology is shown
    -- TBD

    -- Return the marks or nil if empty
    if next(marks) == nil then
        return nil
    else
        return marks
    end
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
        for _, tech in pairs(allowed_tech_names) do
            allowed_set[tech] = true
        end
    end
    if blocked_tech_categories then
        for _, tech in pairs(blocked_tech_categories) do
            blocked_set[tech] = true
        end
    end

    -- Initialize queue with input techs
    for _, tech in pairs(input_tech_names) do
        table.insert(queue, tech)
    end

    -- Main loop (dynamic)
    while #queue > 0 do
        -- Get the first next tech from the queue
        local tech = table.remove(queue, 1)
        if visited[tech] then
            game.print("Skip visited " .. tech)
            goto continue
        end
        visited[tech] = true

        -- Check if current tech is marked
        local marks = get_tech_blocked_marks(owner, tech)
        if marks then
            -- game.print("Tech " .. tech .. " is marked: " .. serpent.line(marks))
            for _, mark in pairs(marks) do

                -- TODO: Validate that we need to stop here if we have a blocked tech array but not a target tech array; 
                -- because if we are going to traverse the whole tech tree every time it might cost valuable UPS
                if blocked_tech_categories and util.array_has_value(blocked_tech_categories, mark) then
                    -- Remove the tech from the visited array
                    visited[tech] = nil
                    -- Remove the successors from further processing
                    for _, suc in pairs(technologies[tech].successors) do
                        game.print("Hmm.. removed successor from the list " .. suc.name)
                        -- pending_prerequisites[suc.name] = nil
                        blacklist_set[suc.name] = true
                    end

                    goto continue
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
            for n, mm in pairs(mark_map) do
                if mm[pre.name] then
                    mm[tech] = true
                    -- game.print(pre.name .. " inherits mark " .. n .. " from " .. pre.name)
                end
                -- BACKLOG: We might need to separate actual blocking tech from inherited marks
            end
        end

        -- Check if current tech is a target tech
        if target_tech_names and util.array_has_value(target_tech_names, tech) then
            table.insert(found_targets, tech)
            if #found_targets == #target_tech_names then
                game.print("We found all target techs!")
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
                game.print("Successor is blacklisted: " .. suc.name)
                goto skip_suc
            end

            -- Skip this successor if not all predecessors are visited
            for _, pre in pairs(suc.prerequisites) do
                if not visited[pre.name] and not pre.researched then
                    -- game.print(serpent.line(visited))
                    goto skip_suc
                end
            end

            -- Skip this successor if it is not in the allow list
            if allowed_tech_names and not allowed_set[suc.name] then
                game.print("Won't visit successor " .. suc.name .. " of parent " .. tech)
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
        local marks = {}
        for mark, prop in pairs(mark_map) do
            if prop[k] then
                table.insert(marks, mark)
            end
        end
        local prop = {
            technology = f.technologies[k],
            visited = true,
            is_blocked = next(marks) ~= nil,
            blocked_reasons = marks
        }
        res[k] = prop
    end

    return res
end

-- Reverse DFS from target technology to every entry node
analyzer.get_upstream_tech_flat = function(force, technology, visited, entry)
    -- Early exit if we already visited this node, or if this tech is not enabled
    if visited[technology.name] or not technology.enabled then
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

analyzer.get_filtered_tech = function(player_index)
    -- local p = game.get_player(player_index)
    -- local f = p.force

    -- -- local gps = storage.state.players[player_index] -- or whatever we called this
    -- local filter = {
    --     allowed_sciences = state.get_player_setting(player_index, "allowed_sciences"),
    --     hide_categories = {},
    --     show_categories = {},
    --     search_text = state.get_player_setting(player_index, "search_text")
    -- }

    -- local tech = {}
    -- for _, t in pairs(f.technologies) do
    --     -- Add the tech to our array if the tech passes the filter
    --     if not get_tech_blocked_marks(player_index, t.name, filter) then
    --         table.insert(tech, t)
    --     end
    -- end
    -- return tech

    ---------- NEW ----------
    local p = game.get_player(player_index)
    local f = p.force

    local entry_tech = get_all_entry_tech(f)
    local res = analyzer.get_downsteam_tech(p, entry_tech)

    -- For now, only return tech that is not blocked
    local arr = {}
    for k, v in pairs(res) do
        if not v.is_blocked then
            table.insert(arr, v.technology)
        end
    end
    return arr
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
    if needle and needle ~= "" and util.fuzzy_search(needle, haystack) then
        return true
    end

    -- Fallback text not found
    return false
end

return analyzer
