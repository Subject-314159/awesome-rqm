local scheduler = {}

local util = require('util')
local const = require('const')
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
    local gf = util.get_global_force(force)
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
    -- Here we don't want to call util.get_global_force because this function can be called before we had the chance to init
    -- Early exit if we don't have a queue
    if not storage.forces or storage.forces[force.index] == nil or storage.forces[force.index].queue == nil then
        return
    end
    local sfq = storage.forces[force.index].queue
    if not sfq then
        return
    end

    -- Clear the permanent storage metadata
    clear_metadata(force)

    -- Clear any remaining technology that was finished in the meantime
    for i = #sfq, 1, -1 do
        if sfq[i].technology and sfq[i].technology.researched then
            table.remove(sfq, i)
        end
    end

    -- Loop over all tech in the queue
    local all_unblocked, all_blocked = {}, {}
    for _, q in pairs(sfq) do
        -- -- Get all technology leading up to and including this technology,
        -- -- and get all the entry tech which are available to be researched
        -- local flatlist_arr, entry = {}, {}
        -- analyzer.get_upstream_tech_flat(force, q.technology, flatlist_arr, entry)

        -- -- Store the entry nodes in the metadata
        -- -- We might (or not) need this info in the near future when we need to queue the next research
        -- q.metadata.entry_nodes = entry

        -- -- Starting from each entry node, get a list of blocked technologies and all successor blocked technologies
        -- local visited_arr, blocked_arr = {}, {}
        -- for _, e in pairs(entry) do
        --     analyzer.get_downsteam_blocked_tech_flat(force, e, flatlist_arr, visited_arr, blocked_arr)
        -- end

        -- -- Convert the key-value arrays to value only arrays
        -- local visited = util.get_array_keys_flat(visited_arr)
        -- local blocked = util.get_array_keys_flat(blocked_arr)

        -- -- At this point visited (and possibly blocked) contains the target tech
        -- -- We don't want this, because we are only interested in the technologies up until (excluding) our target tech
        -- -- So drop the target tech from both arrays
        -- util.array_drop_value(visited, q.technology.name)
        -- util.array_drop_value(blocked, q.technology.name)

        -- -- Get all unblocked technologies based on the visited/blocked list
        -- local unblocked = util.left_excluding_join(visited, blocked)

        -- -- At this point we know:
        -- -- + What all the entry nodes are for this tech
        -- -- + What all the unblocked nodes are towards the final tech
        -- -- + What all the blocked nodes are towards the final tech
        -- -- Now we need to asses which of these nodes are new and which are inherited, and store it in the metadata

        -- local new_unblocked = util.left_excluding_join(unblocked, all_unblocked)
        -- local inherit_unblocked = util.left_excluding_join(unblocked, new_unblocked)
        -- local new_blocked = util.left_excluding_join(blocked, all_blocked)
        -- local inherit_blocked = util.left_excluding_join(blocked, new_blocked)

        -- q.metadata.new_unblocked = new_unblocked or {}
        -- q.metadata.inherit_unblocked = inherit_unblocked or {}
        -- q.metadata.new_blocked = new_blocked or {}
        -- q.metadata.inherit_blocked = inherit_blocked or {}

        -- -- Store all visited technology as predecessors
        -- q.metadata.all_predecessors = visited

        -- -- Additional metadata
        -- q.metadata.is_inherited = util.array_has_value(all_unblocked, q.technology.name) or
        --                               util.array_has_value(all_blocked, q.technology.name)

        -- -- Add the new unblocked and new blocked items to the all unblocked and all blocked items,
        -- -- So we can use them in the next tech refinement loop
        -- util.array_append_array(all_unblocked, q.metadata.new_unblocked)
        -- util.array_append_array(all_blocked, q.metadata.new_blocked)

        -- -- Add the target technology to the all arrays
        -- if blocked == nil or next(blocked) == nil then
        --     -- There are no blocked techs so add the final tech to the unblocked list
        --     table.insert(all_unblocked, q.technology.name)
        -- else
        --     -- There is at least one blocked item on the path, so add it to the blocked list
        --     table.insert(all_blocked, q.technology.name)

        --     -- Also add this flag to the metadata
        --     q.metadata.is_blocked = true
        -- end

        -- NEW --
        -- Get some variables to work with
        local visited, entry, blocking, blocking_reasons, blocked, unblocked = {}, {}, {}, {}, {}, {}
        local tgt
        local tgt_is_blocked = false

        -- Analyze the tech tree for this tech and separate
        local res = analyzer.get_single_tech_force(force.index, q.technology_name)
        for _, t in pairs(res) do
            if t.tech_name == q.technology_name then
                -- This is the target tech
                tgt = t
                if t.is_blocked or t.is_blocking then
                    tgt_is_blocked = true
                end
            else
                -- This is a predecessor
                -- Divide to blocked/unblocked
                local tbl = unblocked
                if t.is_blocked or t.is_blocking then
                    tbl = blocked
                end
                table.insert(tbl, t.tech_name)

                -- Add as blocking
                if t.is_blocking then
                    table.insert(blocking, t.tech_name)
                end

                -- Add to all predecessor array
                table.insert(visited, t.tech_name)
            end

            for _, r in pairs(t.is_blocking_reasons) do
                if not blocking_reasons[r] then
                    blocking_reasons[r] = {}
                end
                table.insert(blocking_reasons[r], t.tech_name)
            end

            -- Populate the entry tech
            if t.is_entry then
                table.insert(entry, t.tech_name)
            end
        end

        -- Store the entry nodes in the metadata
        q.metadata.entry_nodes = entry

        -- Separate blocked/unblocked to new/inherit from previous queued tech
        local new_unblocked = util.left_excluding_join(unblocked, all_unblocked)
        local inherit_unblocked = util.left_excluding_join(unblocked, new_unblocked)
        local new_blocked = util.left_excluding_join(blocked, all_blocked)
        local inherit_blocked = util.left_excluding_join(blocked, new_blocked)

        q.metadata.new_unblocked = new_unblocked or {}
        q.metadata.inherit_unblocked = inherit_unblocked or {}
        q.metadata.new_blocked = new_blocked or {}
        q.metadata.inherit_blocked = inherit_blocked or {}
        q.metadata.blocking_tech = blocking or {}

        -- Store all visited technology as predecessors
        q.metadata.all_predecessors = visited

        -- Additional metadata
        q.metadata.is_inherited = util.array_has_value(all_unblocked, q.technology.name) or
                                      util.array_has_value(all_blocked, q.technology.name)
        q.metadata.blocking_reasons = blocking_reasons

        -- Add the new unblocked and new blocked items to the all unblocked and all blocked items,
        -- So we can use them in the next tech refinement loop
        util.array_append_array(all_unblocked, q.metadata.new_unblocked)
        util.array_append_array(all_blocked, q.metadata.new_blocked)

        -- Add the target technology to the all arrays
        if not tgt_is_blocked then
            -- There are no blocked techs so add the final tech to the unblocked list
            table.insert(all_unblocked, q.technology.name)

            -- Reset the is_blocked mark because it might have been set in a previous stage
            q.metadata.is_blocked = nil
        else
            -- There is at least one blocked item on the path, so add it to the blocked list
            table.insert(all_blocked, q.technology.name)

            -- Also add this flag to the metadata
            q.metadata.is_blocked = true
        end
    end

    -- FOR DEBUGGING
    -- log("===== Recalculated queue =====")
    -- log(serpent.block(sfq))

end

---------------------------------------------------------------------------------------------------
--- Game research queue
---------------------------------------------------------------------------------------------------

local get_queue_dummy_position = function(force)
    local i = 1
    for _, q in pairs(force.research_queue) do
        if q.name == "rqm-dummy-technology" then
            return i
        end
        i = i + 1
    end
    return 0
end

local get_entry_nodes = function(force, tech_name)
    -- Get force from storage or early exit
    local gf = util.get_global_force(force)
    if not gf then
        return
    end

    -- Look for the technology entry in the queue
    for _, q in pairs(gf.queue or {}) do
        if q.technology_name == tech_name then
            return q.metadata.entry_nodes
        end
    end
end

local start_next_from_queue = function(force, overwrite)
    -- Early exit if we have nothing in our queue
    local gf = util.get_global_force(force)
    if #gf.queue == 0 then
        gf.target_queue_tech_name = nil
        return
    end

    -- TODO: Feature: Based on the settings, we might need to have another strategy than just search for the first next available entry node
    for _, q in pairs(gf.queue) do
        -- Check if there is an entry node
        if #q.metadata.entry_nodes > 0 then
            local entry
            for _, e in pairs(q.metadata.entry_nodes) do
                if not util.tech_is_trigger(e) and force.technologies[e].enabled then
                    entry = e
                    break
                end
            end
            if entry then
                -- Store the target queued tech
                -- We need to do it here and not in the next if-block because it might be that we reshuffled the queue without impact
                -- But we still need to remember what the f. we are doing
                gf.target_queue_tech_name = q.technology_name

                -- Only if the entry node is not already in the game queue
                -- Queue the first entry node
                -- Make sure to add our dummy tech in front, so that the trigger knows it's us
                local que = {"rqm-dummy-technology", q.metadata.entry_nodes[1]}
                if next(force.research_queue) == nil or que[2] ~= force.research_queue[1].name or overwrite then
                    -- Enable our dummy tech
                    force.technologies["rqm-dummy-technology"].enabled = true

                    -- Overwrite the in-game queue
                    force.research_queue = que

                    -- Announce if the force has the setting enabled
                    local default = const.default_settings.force.settings_tab.announce_research_started
                    local enbl = state.get_force_setting(force.index, "announce_research_started", default)
                    if enbl then
                        local msg = {"rqm-msg.start-next-research", prototypes.technology[que[2]].localised_name}

                        if util.tech_is_infinite(force, que[2]) then
                            msg[1] = msg[1] .. "-level"
                            table.insert(msg, force.technologies[que[2]].level)
                        end
                        force.print(msg)
                    end
                end

                -- Early exit
                return
            end
        end
    end

    -- If we got here it means we couldn't start a new research, so notify user
    force.print({"rqm-msg.warn-no-researchable-tech"})
    gf.target_queue_tech_name = nil
end

scheduler.start_next_research = function(force)
    -- Early exit if RQM is disabled
    local st = state.get_force_setting(force.index, "master_enable")
    if st == "left" then
        return
    end

    -- Early exit if we don't have our queue initialised yet
    -- TODO: Check if we can get util.get_global_force here
    if not storage.forces or storage.forces[force.index] == nil or storage.forces[force.index].queue == nil then
        return
    end

    -- Check if there is nothing in the queue
    -- if #force.research_queue > 1 then
    -- If there is something in the queue, add it to our internal queue if not yet present
    -- Remove 2nd+ research from the queue
    -- scheduler.recalculate_queue(force)
    -- start_next_from_queue(force, true)
    -- else
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
    -- end

end

---------------------------------------------------------------------------------------------------
--- Internal queue
---------------------------------------------------------------------------------------------------
scheduler.queue_research = function(force, tech_name, position, sneaky)
    -- Check if technology is valid or early exit
    local t = force.technologies[tech_name] or nil
    if not t or not t.valid then
        if tech_name ~= nil or tech_name ~= "" then
            game.print("[RQM] ERROR: Trying to queue technology: '" .. tech_name ..
                           "' but it is not valid, please open a bug report on the mod portal")
        elseif tech_name ~= "rqm-dummy-technology" then
            game.print("[RQM] ERROR: Trying to queue our technology: '" .. tech_name ..
                           "' but it is not valid, please open a bug report on the mod portal")
        end
        return
    end

    -- Check if this research is actually available or early exit
    if not t.enabled and not sneaky then
        force.print({"rqm-msg.warn-queue-disabled", force.technologies[tech_name].localised_name})
    end

    -- TODO: Check if this is a trigger tech
    -- TODO: Check if a tech can have both a trigger and a research, if so check how to deal with it

    -- Init the queue
    init_queue(force)
    local gf = util.get_global_force(force)

    -- Eary exit if this technology is already scheduled
    for _, q in pairs(gf.queue or {}) do
        if q.technology.name == tech_name then
            if not sneaky and tech_name ~= "rqm-dummy-technology" then
                force.print({"rqm-msg.already-queued", q.technology.localised_name})
            end
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
        table.insert(gf.queue, position, prop)
    else
        table.insert(gf.queue, prop)
    end

    -- Early exit if skipping start next research
    if sneaky then
        return
    end

    -- Announce

    -- Announce if the force has the setting enabled
    local default = const.default_settings.force.settings_tab.announce_queue_altered
    local enbl = state.get_force_setting(force.index, "announce_queue_altered", default)
    if enbl and tech_name ~= "rqm-dummy-technology" then
        force.print({"rqm-msg.added-to-queue", t.localised_name})
    end

    -- Recalculate the queue
    scheduler.recalculate_queue(force)

    -- If added to front of queue or our queue only contains one entry then start the next research
    -- if (position and position == 1) or #gf.queue == 1 then
    --     scheduler.start_next_research(force)
    -- end
    scheduler.start_next_research(force)

end
scheduler.on_finished = function(force, tech_name)

    -- Get some variables to work with
    local t = force.technologies[tech_name]
    local tp = prototypes.technology[tech_name]
    local is_infinite = util.tech_is_infinite(force, tech_name)
    local pos = scheduler.get_queue_position(force, tech_name)
    local default = const.default_settings.force.settings_tab.requeue_infinite_tech
    local requeue = state.get_force_setting(force.index, "requeue_infinite_tech", default)

    -- Announce if the force has the setting enabled
    -- This is for research finished
    local default = const.default_settings.force.settings_tab.announce_research_finished
    local enbl = state.get_force_setting(force.index, "announce_research_finished", default)
    if enbl and tech_name ~= "rqm-dummy-technology" then
        local msg = {"rqm-msg.research-finished", t.localised_name}
        if util.tech_is_infinite(force, t.name) then
            msg[1] = msg[1] .. "-level"
            table.insert(msg, t.level - 1)
        end
        force.print(msg)
    end

    -- Check if the technology is an infinite tech
    if is_infinite and pos then
        -- Always remove from queue
        scheduler.remove_from_queue(force, tech_name, true)
        if requeue then
            -- Only requeue if the setting is enabled
            scheduler.queue_research(force, tech_name, nil, true)

            -- Announce if the force has the setting enabled
            -- This is for re-queueing the research
            local default = const.default_settings.force.settings_tab.announce_queue_altered
            local enbl = state.get_force_setting(force.index, "announce_queue_altered", default)
            if enbl then
                force.print({"rqm-msg.requeue-infinite-tech", t.localised_name, t.level})
            end
        end
    end
end

scheduler.queue_dummy = function(force)
    scheduler.queue_research(force, "rqm-dummy-technology", 1)
end

scheduler.clear_queue = function(force)
    -- Init the queue, then clear it
    init_queue(force)
    local gf = util.get_global_force(force)
    gf.queue = {}
end

scheduler.remove_from_queue = function(force, tech_name, sneaky)
    -- Init the queue
    init_queue(force)
    local gf = util.get_global_force(force)

    -- Go through our queue and drop the target tech
    local gfq = gf.queue
    for i, q in pairs(gfq or {}) do
        if q.technology.name == tech_name then
            -- We found our target tech, remove it from our queue
            table.remove(gfq, i)

            -- Early exit if skipping start next research
            if sneaky then
                return
            end

            -- Announce
            local default = const.default_settings.force.settings_tab.announce_queue_altered
            local enbl = state.get_force_setting(force.index, "announce_queue_altered", default)
            if enbl and tech_name ~= "rqm-dummy-technology" then
                force.print({"rqm-msg.removed-from-queue", q.technology.localised_name})
            end

            -- Update the metadata
            scheduler.recalculate_queue(force)

            -- Start the next research
            scheduler.start_next_research(force)
            return
        end
        i = i + 1
    end
end

scheduler.get_queue_position = function(force, tech_name)
    -- Check if technology is valid or early exit
    local t = force.technologies[tech_name] or nil
    if not t or not t.valid then
        return
    end

    -- Get the queued tech index
    local gf = util.get_global_force(force)
    local gfq = gf.queue
    if not gfq then
        return
    end
    for i, q in pairs(gfq) do
        if q.technology.name == tech_name then
            return i
        end
    end
end

scheduler.get_queue_length = function(force)
    -- Init the queue and get the global force
    init_queue(force)
    local gf = util.get_global_force(force)

    -- Return the queue length, or 0 if the queue array does not exist
    return #gf.queue or 0
end

local move_research = function(force, tech_name, old_position, new_position)
    -- Early exit if same position
    if old_position == new_position then
        return
    end

    -- Get a copy of the wueueu item
    local gf = util.get_global_force(force)
    local gfq = gf.queue
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

scheduler.sync_queue = function(force, modified_tech)
    -- This function is called after the user messes with the in-game queue, so we need to reflect that in our queue
    -- The pretty way to do this is to loop through the in-game queue, see where which tech occurs in our queue
    -- including checking for inherited tech, blocked tech, etc
    -- However this makes it pretty messy and difficult to track where exactly to insert what
    -- So we're doing this the lazy way
    -- First we loop over our internal queue and kick out all destination tech that also occurs in the in game queue
    -- Then we will add the in-game queue to the front of our queue
    -- Last, we recalculate our queue then start next research

    -- Check if the queue has our dummy, if so it means that we triggered the event ourselves
    local pos = get_queue_dummy_position(force)
    if pos > 0 then
        -- If pos is 1 then the dummy tech was added at the top, this means that we have overwritten the ingame queue, so we can remove and disable the first tech
        -- If pos is not 1 then we added it at the end of the queue, we can ignore this and the dummy tech will be removed by on_research_finished
        if pos == 1 then
            force.cancel_current_research()
            force.technologies["rqm-dummy-technology"].enabled = false
        end
        return
    end

    -- If we got here and the modified_tech is our dummy tech it means that it got removed from the queue, we can also ignore this and early exit
    if modified_tech == "rqm-dummy-technology" then
        return
    end

    -- Get some variables to work with
    init_queue(force)
    local gf = util.get_global_force(force)
    local gfq = gf.queue

    -- Early exit if there is nothing in the in-game queue because there is nothing to update
    if #force.research_queue == 0 then
        return
    end

    -- Create the array of technology that we need to add to our mods queue
    local iq = 1
    local add = {}
    for it, t in pairs(force.research_queue) do
        -- If we are at the start of both arrays we can check if the in-game queued technology is an entry node for the first technology in our mods queue
        local ispre = false
        if #gfq > 0 then
            if iq == 1 and it == 1 then
                ispre = util.array_has_value(gfq[1].metadata.entry_nodes or {}, t.name)
            end
        end

        -- Check if the technology in the in-game queue matches our queue at the current positions
        -- If they are equal increase the index for our mods queue
        -- If they are not equal we need to add (move) the technology in our mods queue to the correct position
        -- if scheduler.get_queue_position(force, t.name) == it or ispre then
        if #gfq > 0 and iq <= #gfq and gfq[iq].technology_name == t.name then
            iq = iq + 1
        elseif ispre then -- Remove the entry node from the in-game queue
            force.cancel_current_research()
        else
            local prop = {
                pos = iq,
                name = t.name
            }
            table.insert(add, prop)
        end
    end

    -- Kick out all in-game queued tech from our queue
    for _, t in pairs(add) do
        scheduler.remove_from_queue(force, t.name, true)
    end

    -- Add each research to our queue
    for i = #add, 1, -1 do
        local t = add[i]
        scheduler.queue_research(force, t.name, t.pos)
    end

    -- Remember the tick on which the user messed with the ingame queue
    if #add > 0 then
        gf["last_queue_match_tick"] = game.tick
    end

    -- Start next research if the in-game queue is empty
    if #force.research_queue == 0 then
        scheduler.start_next_research(force)
    end
end

return scheduler
