local analyzer = {}

local tech_is_blocked = function(technology)
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
    if tech_is_blocked(technology) or is_blocked then
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

return analyzer
