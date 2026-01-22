--- The queue module is the model in which the mod queue is stored
local state = require("lib.state")
local util = require("lib.util")
local const = require("lib.const")
local analyzer = require("lib.analyzer")

local queue = {}

local get_queue = function(force_index)
    local sf = storage.forces[force_index]
    if not sf or not sf.queue then
        queue.init_force(force_index)
    end
    return storage.forces[force_index].queue
end

local get_simple_queue = function(force_index)
    local sf = storage.forces[force_index]
    if not sf or not sf.simple_queue then
        queue.init_force(force_index)
    end
    return storage.forces[force_index].simple_queue
end

-- local tech_is_available = function(f, t)
--     -- Check if the tech is available i.e. all prerequisites are researched and current tech is not manual trigger
--     local tech = f.technologies[t]
--     if tech.researched then
--         return false
--     end
--     for _, pt in pairs(tech.prerequisites) do
--         if not pt.researched then
--             return false
--         end
--     end
--     local tp = state.get_environment_setting("technology_properties")
--     if tp[t].has_trigger then
--         return false
--     end
--     return true
-- end

local get_first_next_tech = function(force)
    local sfq = get_queue(force.index)

    for _, q in pairs(sfq) do
        local t = state.get_technology(force.index, q.technology_name)
        -- if tech_is_available(force, q.technology_name) then
        if t.available and not t.has_trigger then
            -- The technology is available so queue it
            -- if force.research_queue[1] ~= q.technology_name then
                return q.technology_name
            -- end
        else
            for _, e in pairs(q.metadata.entry_nodes) do
                local et = state.get_technology(force.index, e)
                -- if tech_is_available(force, e) then
                if et.available and not et.has_trigger then
                    -- We have an available entry nodes for this tech, research the first one
                    -- if force.research_queue[1] ~= e then
                        return e
                    -- end
                end
            end
        end
    end
end

queue.init_force = function(force_index)
    if not storage.forces[force_index] then
        storage.forces[force_index] = {}
    end
    local sf = storage.forces[force_index]
    if not sf.queue then
        sf.queue = {}
    end
    if not sf.simple_queue then
        sf.simple_queue = {}
    end
end
local cleanup = function(force_index)
    -- It can be that mods are removed from a save while their tech is still in the queue
    -- So we have to remove it
    local queue = get_queue(force_index)
    for i = #queue, 1, -1 do
        if not queue[i].technology or not queue[i].technology.valid then
            queue[i] = nil
        end
    end
end

queue.init = function()
    if not storage.forces then
        storage.forces = {}
    end
    for _, f in pairs(game.forces) do
        queue.init_force(f.index)
        cleanup(f.index)
        queue.recalculate(f)
    end
end

queue.sync_ingame_queue = function(force)
    -- This function syncs the ingame queue towards the modqueue

    -- Get some variables to work with
    local sfq = get_queue(force.index)

    -- Early exit if there is nothing in the in-game queue because there is nothing to update
    if #force.research_queue == 0 then
        return
    end

    -- Early exit if the ingame queue is 1 and
    if #force.research_queue == 1 then
        local first = get_first_next_tech(force)
        if first == force.research_queue[1].name then
            return
        end
    end

    -- Create the array of technology that we need to add to our mods queue
    local iq = 1
    local add = {}
    for it, t in pairs(force.research_queue) do
        -- If we are at the start of both arrays we can check if the in-game queued technology is an entry node for the first technology in our mods queue
        local ispre = false
        if #sfq > 0 then
            if iq == 1 and it == 1 and sfq[1] then
                ispre = util.array_has_value(sfq[1].metadata.entry_nodes or {}, t.name)
            end
        end

        -- Check if the technology in the in-game queue matches our queue at the current positions
        -- If they are equal increase the index for our mods queue
        -- If they are not equal we need to add (move) the technology in our mods queue to the correct position
        -- if scheduler.get_queue_position(force, t.name) == it or ispre then
        if #sfq > 0 and iq <= #sfq and sfq[iq] and sfq[iq].technology_name == t.name then
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
        queue.remove(force, t.name, true)
    end

    -- Add each research to our queue
    for i = #add, 1, -1 do
        local t = add[i]
        queue.add(force, t.name, t.pos)
    end

    -- Start next research if the in-game queue is empty
    if #force.research_queue == 0 then
        queue.start_next_research(force)
    end

    -- If anything changed we also need to update the GUI
    state.request_gui_update(force)
end

queue.requeue_finished = function(force, tech)
    -- This function requeues finished technology when applicable
    local tp = state.get_environment_setting("technology_properties")

    -- For finite tech levels that are not fully researched yet we only need to request the next stage
    if tech.level and not tp[tech.name].is_infinite and not tech.researched then
        state.request_next_research(force)
        return
    end

    -- For all other cases we have to remove the tech from the queue
    queue.remove(force, tech.name, true)

    -- If it is an infinite tech and requeueing is enabled we have to add it to the end of the queue again
    if tp[tech.name].is_infinite and state.get_force_setting(force.index, "requeue_infinite_tech",
        const.default_settings.force.settings.requeue_infinite_tech) then
        queue.add(force, tech.name)
    end
end

queue.start_next_research = function(force)
    -- This function queues the first next research from our mod queue and clears any subsequent ingamequeued tech
    -- Early exit if no force
    if not force then
        return
    end

    -- Early exit if RQM is disabled
    local st = state.get_force_setting(force.index, "master_enable")
    if st == "left" then
        return
    end

    -- Early exit if we don't have our queue initialised yet
    if not storage.forces or storage.forces[force.index] == nil or storage.forces[force.index].queue == nil then
        return
    end

    -- Early exit if we don't have a queue
    local sfq = get_queue(force.index)
    if not sfq or #sfq == 0 then
        force.research_queue = nil
        return
    end

    -- Recalculate the queue
    queue.recalculate(force)

    -- Queue the next research
    local next = get_first_next_tech(force)
    if next then
        -- Queue the first next technology
        if force.research_queue and #force.research_queue == 1 and force.research_queue[1] ~= next then
            force.research_queue = {next}
        end
    else
        -- Notify user because we are unable to queue anything
        game.print("[RQM] - Unable to queue next research because preconditions are blocked")
    end

end

local clear_metadata = function(f)
    local queue = get_queue(f.index)
    for k, v in pairs(queue or {}) do
        v.metadata = {}
    end

    -- Clear the storage.forces.queue.blocked and .unblocked
    -- queue.blocked={}
    -- queue.unblocked={}

end

queue.recalculate = function(f)
    -- This function recalculates the ingame queue, i.e. add metadata

    -- Early exit if we don't have a queue
    if not f then
        return
    end
    local sfq = get_queue(f.index)
    if not sfq or #sfq == 0 then
        return
    end

    -- Clear the permanent storage metadata
    clear_metadata(f)

    -- Clear any remaining technology that was finished in the meantime
    for i = #sfq, 1, -1 do
        if sfq[i] and sfq[i].technology ~= nil and sfq[i].valid then
            if sfq[i].technology.researched then
                table.remove(sfq, i)
            end
        elseif sfq[i] then
            table.remove(sfq, i)
        end
    end

    -- NEW --
    local rolling_queue = {}
    local rolling_inherit = {}
    for _, q in pairs(sfq) do
        -- Get the technology state
        local t = state.get_technology(f.index, q)

        -- Init empty arrays
        local arr={"blocking_reasons", "entry_nodes", "new_unblocked", "inherit_unblocked", "all_unblocked", "new_blocked", "inherit_blocked", "all_blocked", "inherit_by"}
        for _,prop in pairs(arr) do
            q.metadata[prop] = {}
        end
        
        --Get inherit by tech
        for _, rq in pairs(rolling_queue) do
            if util.array_has_value(t.all_prerequisites, rq) then
                table.insert(q.metadata.inherit_by, rq)
            end
        end
        q.metadata.is_inherited = (#inherit_by > 0)

        -- Get specific prerequisites properties
        -- local new_unblocked, inherit_unblocked, all_unblocked = {}, {}, {}
        -- local new_blocked, inherit_blocked, all_blocked = {}, {}, {}
        for pre, _ in pairs(t.all_prerequisites) do
            -- Get the prerequisite state
            local pt = state.get_technology(f.index, pre)
            if pt.researched then
                game.print("Hmm we have an anomaly.. Found a prerequisite in state but it is already researched")
                goto continue
            end
            
            -- Get array of prerequisites by new/inherit/all un-/blocked
            local is_new = util.array_has_value(rolling_inherit, pre)
            if pt.has_trigger or not pt.enabled or pt.hidden or pt.blocked_by then
                if is_new then
                    table.insert(q.metadata.new_blocked, pre)
                else
                    table.insert(q.metadata.inherit_unblocked, pre)
                end
                table.insert(q.metadata.all_blocked,pre)
                q.metadata.is_blocked = true
            else
                if is_new then
                    table.insert(q.metadata.new_unblocked, pre)
                else
                    table.insert(q.metadata.inherit_unblocked, pre)
                end
                table.insert(q.metadata.all_unblocked, pre)
            end

            --Get blocked tech
            if pt.has_trigger or not pt.enabled or pt.hidden then
                -- Trigger tech
                if pt.has_trigger then
                    -- Init reason array
                    local reason = "tech_is_manual_trigge"
                    if not q.metadata.blocking_reasons[reason] then q.metadata.blocking_reasons[reason] = {} end
                    -- Add to metadata
                    table.insert(q.metadata.blocking_reasons[reason],pre)
                end

                -- Disabled/hidden tech
                if not pt.enabled or pt.hidden then
                    -- Init reason array
                    local reason = "tech_is_not_enabled"
                    if not q.metadata.blocking_reasons[reason] then q.metadata.blocking_reasons[reason] = {} end
                    -- Add to metadata
                    table.insert(q.metadata.blocking_reasons[reason],pre)
                end
            end

            -- Append prerequisite to rolling inherit array
            if is_new then
                table.insert(rolling_inherit, pre)
            end

            ::continue::
        end
        q.metadata.all_predecessors = t.all_prerequisites

        -- Add the current queued tech to the rolling tech array
        table.insert(rolling_queue, q.technology_name)
    end


    
    -- OLD --
    -- Loop over all tech in the queue
    -- local all_unblocked, all_blocked = {}, {}
    -- for _, q in pairs(sfq) do
    --     -- Get some variables to work with
    --     local visited, entry, blocking, blocking_reasons, blocked, unblocked = {}, {}, {}, {}, {}, {}
    --     local tgt
    --     local tgt_is_blocked = false

    --     -- Analyze the tech tree for this tech and separate
    --     local res = analyzer.get_single_tech_force(f.index, q.technology_name)
    --     for _, t in pairs(res) do
    --         if t.tech_name == q.technology_name then
    --             -- This is the target tech
    --             tgt = t
    --             if t.is_blocked or t.is_blocking then
    --                 tgt_is_blocked = true
    --             end
    --         else
    --             -- This is a predecessor
    --             -- Divide to blocked/unblocked
    --             local tbl = unblocked
    --             if t.is_blocked or t.is_blocking then
    --                 tbl = blocked
    --             end
    --             table.insert(tbl, t.tech_name)

    --             -- Add as blocking
    --             if t.is_blocking then
    --                 table.insert(blocking, t.tech_name)
    --             end

    --             -- Add to all predecessor array
    --             table.insert(visited, t.tech_name)
    --         end

    --         for _, r in pairs(t.is_blocking_reasons) do
    --             if not blocking_reasons[r] then
    --                 blocking_reasons[r] = {}
    --             end
    --             table.insert(blocking_reasons[r], t.tech_name)
    --         end

    --         -- Populate the entry tech
    --         if t.is_entry then
    --             table.insert(entry, t.tech_name)
    --         end
    --     end

    --     -- Store the entry nodes in the metadata
    --     q.metadata.entry_nodes = entry

    --     -- Separate blocked/unblocked to new/inherit from previous queued tech
    --     local new_unblocked = util.left_excluding_join(unblocked, all_unblocked)
    --     local inherit_unblocked = util.left_excluding_join(unblocked, new_unblocked)
    --     local new_blocked = util.left_excluding_join(blocked, all_blocked)
    --     local inherit_blocked = util.left_excluding_join(blocked, new_blocked)

    --     q.metadata.new_unblocked = new_unblocked or {}
    --     q.metadata.inherit_unblocked = inherit_unblocked or {}
    --     q.metadata.new_blocked = new_blocked or {}
    --     q.metadata.inherit_blocked = inherit_blocked or {}
    --     q.metadata.blocking_tech = blocking or {}

    --     -- Store all visited technology as predecessors
    --     q.metadata.all_predecessors = visited

    --     -- Additional metadata
    --     q.metadata.is_inherited = util.array_has_value(all_unblocked, q.technology.name) or
    --                                   util.array_has_value(all_blocked, q.technology.name)
    --     q.metadata.blocking_reasons = blocking_reasons

    --     -- Add the new unblocked and new blocked items to the all unblocked and all blocked items,
    --     -- So we can use them in the next tech refinement loop
    --     util.array_append_array(all_unblocked, q.metadata.new_unblocked)
    --     util.array_append_array(all_blocked, q.metadata.new_blocked)

    --     -- Add the target technology to the all arrays
    --     if not tgt_is_blocked then
    --         -- There are no blocked techs so add the final tech to the unblocked list
    --         table.insert(all_unblocked, q.technology.name)

    --         -- Reset the is_blocked mark because it might have been set in a previous stage
    --         q.metadata.is_blocked = nil
    --     else
    --         -- There is at least one blocked item on the path, so add it to the blocked list
    --         table.insert(all_blocked, q.technology.name)

    --         -- Also add this flag to the metadata
    --         q.metadata.is_blocked = true
    --     end
    -- end

    -- Match the queue to the simple queue
    local simp = get_simple_queue(f.index)
    for i = #simp, 1, -1 do
        table.remove(simp, i)
    end
    for _, q in pairs(sfq) do
        table.insert(simp, q.technology_name)
    end

    -- FOR DEBUGGING
    -- log("===== Recalculated queue =====")
    -- log(serpent.block(sfq))

end

---@param f LuaForce
---@param n string technology name
---@param p int position
queue.add = function(f, n, p)
    -- This function adds a new technology to the modqueue
    -- If no position is given assume append at the end
    -- Check if technology is valid or early exit
    local t = f.technologies[n]
    if not t or not t.valid then
        if t.name and (t.name ~= nil or t.name ~= "") then
            game.print("[RQM] ERROR: Trying to queue technology: '" .. t.name ..
                           "' but it is not valid, please open a bug report on the mod portal")
        else
            game.print("[RQM] ERROR: Trying to queue technology: '" .. serpent.line(t) ..
                           "' but it is not valid, please open a bug report on the mod portal")
        end
        return
    end

    -- Check if this research is actually available or early exit
    if not t.enabled then
        f.print({"rqm-msg.warn-queue-disabled", t.localised_name})
    end

    local sfq = get_queue(f.index)

    -- Eary exit if this technology is already scheduled
    for _, q in pairs(sfq or {}) do
        if q.technology.name == t.name then
            -- TODO: If the user adds an infinite tech multiple times to the in-game queue we need to trigger the auto clean-up
            f.print({"rqm-msg.already-queued", q.technology.localised_name})
            return
        end
    end

    -- Add the tech to our queue
    local prop = {
        technology = t,
        technology_name = t.name,
        metadata = {}
    }
    if p then
        table.insert(sfq, p, prop)
    else
        table.insert(sfq, prop)
    end

    -- Announce
    f.print({"rqm-msg.added-to-queue", t.localised_name})

    -- Recalculate
    queue.recalculate(f)

    -- Request next research and gui refresh
    state.update_technology_queued(f.index, t.name)
    state.request_next_research(f)
    state.request_gui_update(f)
end

queue.remove = function(f, n, silent)
    -- This function removes a technology from the modqueue

    -- Go through our queue and drop the target tech
    local sfq = get_queue(f.index)
    for i, q in pairs(sfq or {}) do
        if q.technology.name == n then
            -- We found our target tech, remove it from our queue
            table.remove(sfq, i)
            -- table.remove(simp, i)

            -- Announce
            if not silent then
                f.print({"rqm-msg.removed-from-queue", q.technology.localised_name})
            end

            -- Recalculate
            queue.recalculate(f)

            -- Request next research and gui refresh
            state.update_technology_queued(f.index, n)
            state.request_next_research(f)
            state.request_gui_update(f)

            -- Exit because there is nothing more to do
            return
        end
        i = i + 1
    end

end

local get_queue_position = function(force, tech_name)
    -- Check if technology is valid or early exit
    local t = force.technologies[tech_name] or nil
    if not t or not t.valid then
        return
    end

    -- Get the queued tech index
    local sfq = get_queue(force.index)
    if not sfq then
        return
    end
    for i, q in pairs(sfq) do
        if q.technology.name == tech_name then
            return i
        end
    end
end

local get_queue_length = function(force)
    -- Init the queue and get the global force
    local sfq = get_queue(force.index)

    -- Return the queue length, or 0 if the queue array does not exist
    return #sfq or 0
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

    -- Recalculate
    queue.recalculate(force)

    -- Request next research and gui refresh
    state.request_next_research(force)
    state.request_gui_update(force)

end

queue.promote = function(force, tech_name, steps)
    -- Check if technology is valid or early exit
    local t = force.technologies[tech_name] or nil
    if not t or not t.valid then
        return
    end

    -- Get the current index and length
    local i = get_queue_position(force, tech_name)

    -- Calculate new position
    local new_position
    if i - steps < 1 then
        new_position = 1
    else
        new_position = i - steps
    end

    -- Early exit if this tech is already at position 1 or the current position is equal to the promoted position
    if i == 1 then
        return
    end

    move_research(force, tech_name, i, new_position)
end

queue.demote = function(force, tech_name, steps)
    -- Check if technology is valid or early exit
    local t = force.technologies[tech_name] or nil
    if not t or not t.valid then
        return
    end

    -- Get the current index and length
    local i = get_queue_position(force, tech_name)
    local l = get_queue_length(force)

    -- Calculate new position
    local new_position
    if i + steps > l then
        new_position = l
    else
        new_position = i + steps
    end

    -- Early exit if this tech is already at the end or the current position is equal to the promoted position
    if i == l or i == new_position then
        return
    end

    move_research(force, tech_name, i, new_position or i + 1)
end

queue.clean_ingame_queue_timeout = function(f)
    -- This function is to be called after a timeout when the user changes the ingame queue
    -- At the point this function is called we don't know what caused it
    -- To check wether cleanup is actually needed we can check the following;
    -- if the length is 0 or 1 and the tech matches one of the entry tech from our modqueue,
    -- then we don't have to clean up the ingame queue
    -- Note: We might have a ingame queue length of 0 and a modqueue length of >0
    -- when all modqueued tech are blocked
    -- if the length is >1 then a clean up is needed
end

queue.clear = function(f)
    -- This function clears the ingame queue
    local sfq = get_queue(f.index)
    if not sfq then
        return
    end
    for i = #sfq, 1, -1 do
        if sfq[i] and sfq[i].technology_name then
            queue.remove(f, sfq[i].technology_name)
        end
    end

    -- Clear force ingame queue and request GUI update
    f.research_queue = {}
    state.request_gui_update(f)
end

return queue
