local scheduler = {}

local util = require('util')

scheduler.init = function()
    -- Init the storage array
    if not storage then
        storage = {}
    end

    -- Init the forces array
    if not storage.forces then
        storage.forces = {}
    end
    for _, p in pairs(game.players) do
        if not storage.forces[p.force.index] then
            storage.forces[p.force.index] = {}
        end
    end
end

local init_queue = function(force)
    if not storage or not storage.forces then
        scheduler.init()
    end

    local gf = storage.forces[force.index]
    if not gf.queue then
        gf.queue = {}
    end
end

local tech_is_blocked = function(technology)
    -- Check if the technology is blocked according to our rules

    -- Rule 1: The technology requires a trigger to unblock
    -- Get the prototype from the technology and check if a research_trigger exists
    local p = prototypes.technology[technology.name]
    if p.research_trigger ~= nil then
        return true
    end
end

local get_blocked_tech_flat
-- DFS from an entry node through all allowed techs (from previous flatlist) and get all blocked tech and their successors
get_blocked_tech_flat = function(force, tech_name, allowed, visited, blocked, predecessor_is_blocked)
    -- Is_blocked is to be passed by value instead of by reference because we are only interested in the downstream value
    local is_blocked = predecessor_is_blocked or false

    -- Early exit if we already visited this node
    -- TODO: When checking for blocked we should check the blocked node as well
    if visited[tech_name] then
        return
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
            get_blocked_tech_flat(force, tech_name, allowed, visited, blocked, is_blocked)
        end
    end
end

local get_all_tech_flat
-- Reverse DFS from target technology to every entry node
get_all_tech_flat = function(force, technology, visited, entry)
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
                get_all_tech_flat(force, p, visited, entry)
            end
        end
    end
end

local clear_metadata = function(force)
    -- Clear the storage.forces.queue.metdata
    for k, v in pairs(storage.forces.queue or {}) do
        v.metadata = {}
    end

    -- Clear the storage.forces.blocked and .unblocked
    storage.forces.blocked = {}
    storage.forces.unblocked = {}

end

-- While this is a public function, it should be called at a minimum on itself
scheduler.recalculate_queue = function(force)
    -- Clear the permanent storage metadata
    clear_metadata(force)

    -- Loop over all tech in the queue
    local all_unblocked, all_blocked = {}, {}
    for _, q in pairs(storage.forces[force.index].queue) do
        -- Get all technology leading up to and including this technology,
        -- and get all the entry tech which are available to be researched
        local flatlist, entry = {}, {}
        get_all_tech_flat(force, q.technology, flatlist, entry)

        -- Store the entry nodes in the metadata
        -- We might (or not) need this info in the near future when we need to queue the next research
        q.metadata.entry_nodes = entry

        -- Starting from each entry node, get a list of blocked technologies and all successor blocked technologies
        local visited, blocked = {}, {}
        game.print("Blocked before: " .. serpent.line(blocked))
        for _, e in pairs(entry) do
            get_blocked_tech_flat(force, e, flatlist, visited, blocked)
        end
        game.print("Blocked: " .. serpent.line(blocked))

        -- At this point visited (and possibly blocked) contains the target tech
        -- We don't want this, because we are only interested in the technologies up until (excluding) our target tech
        -- So drop the target tech from both arrays
        util.array_drop_value(visited, q.technology.name)
        util.array_drop_value(blocked, q.technology.name)

        -- Get all unblocked technologies based on the visited/blocked list
        local unblocked = util.left_excluding_join(visited, blocked)

        -- At this point we know:
        -- + What all the entry nodes are for this tech
        -- + What all the unblocked nodes are towards the final tech
        -- + What all the blocked nodes are towards the final tech
        -- Now we need to asses which of these nodes are new and which are inherited, and store it in the metadata

        q.metadata.new_unblocked = util.left_excluding_join(unblocked, all_unblocked) or {}
        q.metadata.inherit_unblocked = util.left_excluding_join(all_unblocked, unblocked) or {}
        q.metadata.new_blocked = util.left_excluding_join(blocked, all_blocked) or {}
        q.metadata.inherit_blocked = util.left_excluding_join(all_blocked, blocked) or {}

        -- Add the new unblocked and new blocked items to the all unblocked and all blocked items,
        -- So we can use them in the next tech refinement loop
        util.array_append_array(all_unblocked, q.metadata.new_unblocked)
        util.array_append_array(all_blocked, q.metadata.new_blocked)

        -- Add the target technology to the all arrays
        if next(blocked) == nil then
            -- There are no blocked techs so add the final tech to the unblocked list
            table.insert(all_unblocked, q.technology.name)
        else
            -- There is at least one blocked item on the path, so add it to the blocked list
            table.insert(all_blocked, q.technology.name)

            -- Also add this flag to the metadata
            q.metadata.is_blocked = true
        end

    end

    log("=== Updated research queue ===")
    log(serpent.block(storage.forces[force.index]))

end

---------------------------------------------------------------------------------------------------
--- Game research queue
---------------------------------------------------------------------------------------------------

local start_next_from_queue = function(force)
    game.print("start next 1")
    -- TODO: Feature: Based on the settings, we might need to have another strategy than just search for the first next available entry node
    for _, q in pairs(storage.forces[force.index].queue) do
        -- Check if there is an entry node
        if #q.metadata.entry_nodes > 0 then
            -- Queue the first entry node

            local que = {q.metadata.entry_nodes[1]}
            force.research_queue = que
            return
        end
    end

    -- If we got here it means we couldn't start a new research, so notify user
    game.print('[RQM] Unable to start next research')
end

scheduler.start_next_research = function(force)
    -- Check if there is nothing in the queue

    if #force.research_queue > 0 then
        -- If there is something in the queue, add it to our internal queue if not yet present
        -- Remove 2nd+ research from the queue
    else
        -- If there is nothing in the queue, add our first next research to the queue
        -- Loop through our queue
        if #storage.forces[force.index].queue then
            start_next_from_queue(force)
        else
            -- There is nothing in our queue, check if auto research is enabled and start the first next thing to do
            -- TODO: Needs to be implemented
        end
    end

end

---------------------------------------------------------------------------------------------------
--- Internal queue
---------------------------------------------------------------------------------------------------
scheduler.queue_research = function(force, tech_name, add_to_front_of_queue)
    -- Check if technology is valid or early exit
    local t = force.technologies[tech_name] or nil
    if not t or not t.valid then
        return
    end

    -- Check if this research is actually available or early exit
    if not t.enabled then
        game.print("[RQM] Error: Trying to queue technology " .. t.name .. " but it is not enabled")
    end

    -- TODO: Check if this is a trigger tech
    -- TODO: Check if a tech can have both a trigger and a research, if so check how to deal with it

    -- Init the queue
    init_queue(force)

    -- Eary exit if this technology is already scheduled
    for _, q in pairs(storage.forces[force.index].queue or {}) do
        if q.technology.name == tech_name then
            game.print("[RQM] Technology " .. serpent.line(q.technology.localised_name) .. " is already scheduled")
            return
        end
    end

    -- Add the technology entry to the storage queue
    local prop = {
        technology = t,
        technology_name = t.name,
        metadata = {}
    }
    if add_to_front_of_queue then
        table.insert(storage.forces[force.index].queue, 1, prop)
    else
        table.insert(storage.forces[force.index].queue, prop)
    end

    -- Recalculate the queue
    scheduler.recalculate_queue(force)

    -- If added to front of queue or our queue only contains one entry then start the next research
    if add_to_front_of_queue or #storage.forces[force.index].queue == 1 then
        scheduler.start_next_research(force)
    end

end

scheduler.clear_queue = function(force)
    -- Init the queue
    init_queue(force)

    -- Clear the queue
    storage.forces[force.index] = {}
end

return scheduler
