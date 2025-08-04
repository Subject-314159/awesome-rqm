local scheduler = {}

local util = require('util')
local state = require('state')
local analyzer = require('analyzer')

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
    if not storage or next(storage) == nil or not storage.forces or next(storage.forces) == nil then
        scheduler.init()
    end

    local gf = storage.forces[force.index]
    if not gf.queue then
        gf.queue = {}
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
    -- Early exit if we don't have a queue
    local sfq = storage.forces[force.index].queue
    if not sfq then
        return
    end

    -- Clear the permanent storage metadata
    clear_metadata(force)

    -- Clear any remaining technology that was finished in the meantime
    for i = #sfq, 1, -1 do
        if sfq[i].technology.researched then
            table.remove(sfq, i)
        end
    end

    -- Loop over all tech in the queue
    local all_unblocked, all_blocked = {}, {}
    for _, q in pairs(sfq) do
        -- Get all technology leading up to and including this technology,
        -- and get all the entry tech which are available to be researched
        local flatlist_arr, entry = {}, {}
        analyzer.get_upstream_tech_flat(force, q.technology, flatlist_arr, entry)

        -- Store the entry nodes in the metadata
        -- We might (or not) need this info in the near future when we need to queue the next research
        q.metadata.entry_nodes = entry

        -- Starting from each entry node, get a list of blocked technologies and all successor blocked technologies
        local visited_arr, blocked_arr = {}, {}
        for _, e in pairs(entry) do
            analyzer.get_downsteam_blocked_tech_flat(force, e, flatlist_arr, visited_arr, blocked_arr)
        end

        -- Convert the key-value arrays to value only arrays
        local visited = util.get_array_keys_flat(visited_arr)
        local blocked = util.get_array_keys_flat(blocked_arr)

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

        local new_unblocked = util.left_excluding_join(unblocked, all_unblocked)
        local inherit_unblocked = util.left_excluding_join(unblocked, new_unblocked)
        local new_blocked = util.left_excluding_join(blocked, all_blocked)
        local inherit_blocked = util.left_excluding_join(blocked, new_blocked)

        q.metadata.new_unblocked = new_unblocked or {}
        q.metadata.inherit_unblocked = inherit_unblocked or {}
        q.metadata.new_blocked = new_blocked or {}
        q.metadata.inherit_blocked = inherit_blocked or {}

        -- Add the new unblocked and new blocked items to the all unblocked and all blocked items,
        -- So we can use them in the next tech refinement loop
        util.array_append_array(all_unblocked, q.metadata.new_unblocked)
        util.array_append_array(all_blocked, q.metadata.new_blocked)

        -- Add the target technology to the all arrays
        if blocked == nil or next(blocked) == nil then
            -- There are no blocked techs so add the final tech to the unblocked list
            table.insert(all_unblocked, q.technology.name)
        else
            -- There is at least one blocked item on the path, so add it to the blocked list
            table.insert(all_blocked, q.technology.name)

            -- Also add this flag to the metadata
            q.metadata.is_blocked = true
        end
    end

    -- log("=== Final updated research queue ===")
    -- log(serpent.block(storage.forces[force.index]))

end

---------------------------------------------------------------------------------------------------
--- Game research queue
---------------------------------------------------------------------------------------------------

local start_next_from_queue = function(force, overwrite)
    -- Early exit if we have nothing in our queue
    if #storage.forces[force.index].queue == 0 then
        return
    end

    -- TODO: Feature: Based on the settings, we might need to have another strategy than just search for the first next available entry node
    for _, q in pairs(storage.forces[force.index].queue) do
        -- Check if there is an entry node
        if #q.metadata.entry_nodes > 0 then
            -- Queue the first entry node

            local que = {q.metadata.entry_nodes[1]}
            -- Only if the entry node is not already in the game queue
            if next(force.research_queue) == nil or que[1] ~= force.research_queue[1].name or overwrite then
                force.research_queue = que
                force.print({"rqm-msg.start-next-research", prototypes.technology[que[1]].localised_name})
            end

            -- Early exit
            return
        end
    end

    -- If we got here it means we couldn't start a new research, so notify user
    game.print("[RQM] ERROR: Unable to start next research, please open a bug report on the mod portal")
end

scheduler.start_next_research = function(force)
    -- Early exit if RQM is disabled
    local st = state.get_force_setting(force.index, "master_enable")
    if st == "left" then
        return
    end

    -- Check if there is nothing in the queue

    if #force.research_queue > 1 then
        -- If there is something in the queue, add it to our internal queue if not yet present
        -- Remove 2nd+ research from the queue
        -- scheduler.recalculate_queue(force)
        -- start_next_from_queue(force, true)
    else
        -- If there is nothing in the queue, add our first next research to the queue
        -- Loop through our queue
        if storage.forces[force.index].queue and #storage.forces[force.index].queue > 0 then
            start_next_from_queue(force)
        else
            -- There is nothing in our queue, check if auto research is enabled and start the first next thing to do
            -- TODO: Needs to be implemented
            -- For now: Just clear the game research queue
            force.research_queue = {}
        end
    end

end

---------------------------------------------------------------------------------------------------
--- Internal queue
---------------------------------------------------------------------------------------------------
scheduler.queue_research = function(force, tech_name, position)
    -- Check if technology is valid or early exit
    local t = force.technologies[tech_name] or nil
    if not t or not t.valid then
        return
    end

    -- Check if this research is actually available or early exit
    if not t.enabled then
        game.print("[RQM] Error: Trying to queue technology " .. t.name ..
                       " but it is not enabled, please open a bug report on the mod portal")
    end

    -- TODO: Check if this is a trigger tech
    -- TODO: Check if a tech can have both a trigger and a research, if so check how to deal with it

    -- Init the queue
    init_queue(force)

    -- Eary exit if this technology is already scheduled
    for _, q in pairs(storage.forces[force.index].queue or {}) do
        if q.technology.name == tech_name then
            force.print({"rqm-msg.already-queued", q.technology.localised_name})
            return
        end
    end

    -- Add the technology entry to the storage queue
    local prop = {
        technology = t,
        technology_name = t.name,
        metadata = {}
    }
    if position then
        table.insert(storage.forces[force.index].queue, position, prop)
    else
        table.insert(storage.forces[force.index].queue, prop)
    end
    force.print({"rqm-msg.added-to-queue", t.localised_name})

    -- Recalculate the queue
    scheduler.recalculate_queue(force)

    -- If added to front of queue or our queue only contains one entry then start the next research
    if position or #storage.forces[force.index].queue == 1 then
        scheduler.start_next_research(force)
    end

end

scheduler.clear_queue = function(force)
    -- Init the queue
    init_queue(force)

    -- Clear the queue
    storage.forces[force.index] = {}
end

scheduler.remove_from_queue = function(force, tech_name)
    -- Init the queue
    init_queue(force)

    -- Go through our queue and drop the target tech
    local gfq = storage.forces[force.index].queue
    local i = 1
    for _, q in pairs(gfq or {}) do
        if q.technology.name == tech_name then
            -- We found our target tech, remove it from our queue
            table.remove(gfq, i)
            force.print({"rqm-msg.removed-from-queue", q.technology.localised_name})

            -- Update the metadata
            scheduler.recalculate_queue(force)

            -- Start the next research
            scheduler.start_next_research(force)
            return
        end
        i = i + 1
    end

    -- If we got here something is wrong (or not, because now we force remove without checking existence)
    -- game.print("[RQM] ERROR: Failed to remove technology from queue: " .. tech_name)
end

scheduler.get_queue_position = function(force, tech_name)
    -- Check if technology is valid or early exit
    local t = force.technologies[tech_name] or nil
    if not t or not t.valid then
        return
    end

    -- Get the queued tech index
    local gfq = storage.forces[force.index].queue
    for i, q in pairs(gfq) do
        if q.technology.name == tech_name then
            return i
        end
    end
end

scheduler.get_queue_length = function(force)
    -- Early exit if there is no forces array or the force is not indexed
    if not storage.forces or not storage.forces[force.index] then
        return
    end

    -- Return the queue length, or 0 if the queue array does not exist
    return #storage.forces[force.index].queue or 0
end

local move_research = function(force, tech_name, old_position, new_position)
    -- Early exit if same position
    if old_position == new_position then
        return
    end

    -- Get a copy of the wueueu item
    local gfq = storage.forces[force.index].queue
    local prop = gfq[old_position]

    -- Remove the old position
    table.remove(gfq, old_position)

    -- Insert the item on the new position
    table.insert(gfq, new_position, prop)

    -- Start the next research based on the updated queue
    scheduler.recalculate_queue(force)
    scheduler.start_next_research(force)

end

scheduler.promote_research = function(force, tech_name, new_position)
    -- Check if technology is valid or early exit
    local t = force.technologies[tech_name] or nil
    if not t or not t.valid then
        return
    end

    -- Get the current index and length
    local i = scheduler.get_queue_position(force, tech_name)

    -- Early exit if this tech is already at position 1 or the current position is equal to the promoted position
    if i == 1 then
        return
    end

    move_research(force, tech_name, i, new_position or i - 1)
end

scheduler.demote_research = function(force, tech_name, new_position)
    -- Check if technology is valid or early exit
    local t = force.technologies[tech_name] or nil
    if not t or not t.valid then
        return
    end

    -- Get the current index and length
    local i = scheduler.get_queue_position(force, tech_name)
    local l = scheduler.get_queue_length(force)

    -- Early exit if this tech is already at position 1 or the current position is equal to the promoted position
    if i == l or i == new_position then
        return
    end

    move_research(force, tech_name, i, new_position or i + 1)
end

scheduler.match_queue = function(force)
    -- This function is called after the user messes with the in-game queue, so we need to reflect that in our queue
    -- The pretty way to do this is to loop through the in-game queue, see where which tech occurs in our queue
    -- including checking for inherited tech, blocked tech, etc
    -- However this makes it pretty messy and difficult to track where exactly to insert what
    -- So we're doing this the lazy way
    -- First we loop over our internal queue and kick out all destination tech that also occurs in the in game queue
    -- Then we will add the in-game queue to the front of our queue
    -- Last, we recalculate our queue then start next research

    -- Get some variables to work with
    local gf = storage.forces[force.index]
    local gfq = gf.queue

    -- Early exit if we caused this trigger by starting the next research
    -- In the case there is only one item in the in-game queue and that item is the first next research
    -- it means that our script added a new tech to the in-game queue, so we ignore this trigger
    if #force.research_queue == 1 and util.array_has_value(gfq[1].metadata.entry_nodes, force.research_queue[1].name) then
        -- game.print("Ignoring match queue: The only in-game queue'd tech is one of our entry nodes")
        return
    end

    -- Remember the tick on which the in-game queue got updated
    gf["last_queue_match_tick"] = game.tick

    -- Early exit if there is nothing in the in-game queue because there is nothing to update
    if #force.research_queue == 0 then
        return
    end

    -- Kick out all in-game queued tech from our queue
    for k, v in pairs(force.research_queue) do
        scheduler.remove_from_queue(force, v.name)
    end

    -- Add in-game queued tech to the top of our queue, iterating reversed over in-game queue
    -- First make a copy of the in-game queue;
    -- our function might reset the in-game queue
    -- we want to skip our dummy tech
    local que = {}
    for i = #force.research_queue, 1, -1 do
        -- Skip our dummy queue
        if force.research_queue[i].name == "rqm-dummy-technology" then
            goto continue
        end
        table.insert(que, force.research_queue[i].name)
        ::continue::
    end

    -- Add each research to our queue
    for _, q in pairs(que) do
        scheduler.queue_research(force, q, 1)
    end

    -- Clear the in-game queue and start next research
    -- force.research_queue = {}
    -- scheduler.start_next_research(force)

end

return scheduler
