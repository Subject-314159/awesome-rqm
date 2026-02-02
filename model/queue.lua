--- The queue module is the model in which the mod queue is stored
local util = require("lib.util")
local const = require("lib.const")
local state = require("model.state")
local tech = require("model.tech")
local lab = require("model.lab")

local queue = {}

-- Data model
-- storage.forces[force_index].queue.queue = {"tech-1", ...}

local keys = {
    queue = "queue",
    current_tech = "current_tech",
    misses_science = "misses_science",
    announced_blocked = "announced_blocked"
}

---------------------------------------------------------------------------
-- Internal queue helpers
---------------------------------------------------------------------------

local set = function(force_index, key, val)
    if not storage.forces[force_index] then
        return
    end
    storage.forces[force_index].queue[key] = val
end
local get = function(force_index, key)
    return storage.forces[force_index].queue[key]
end

local tech_is_available = function(xcur)
    return xcur and not xcur.technology.researched and xcur.available and xcur.technology.enabled and
               not xcur.meta.has_trigger
end
local science_is_available = function(xcur, lsci)
    for _, s in pairs(xcur.meta.sciences or {}) do
        if not lsci[s] then
            return false
        end
    end
    return true
end
local get_first_next_tech = function(f)
    -- This function returns the first next available technology as required to progress in the queue
    local sfq = get(f.index, keys.queue)
    local lsci = lab.get_labs_fill_rate(f.index)

    -- Reset current researching tech
    set(f.index, keys.current_tech, nil)

    -- Reset & get missing science array
    set(f.index, keys.misses_science, {})
    local sfsci = get(f.index, keys.misses_science)

    for _, q in pairs(sfq or {}) do
        local xcur = tech.get_single_tech_state_ext(f.index, q)
        if tech_is_available(xcur) then
            if science_is_available(xcur, lsci) then
                -- Remember that we are researching current tech
                set(f.index, keys.current_tech, q)

                -- Return the current tech name
                return q
            else
                -- Mark that this tech misses science
                sfsci[q] = true
            end
        else
            local misses_science = false
            for pre, _ in pairs(xcur.meta.all_prerequisites or {}) do
                local xpre = tech.get_single_tech_state_ext(f.index, pre)
                if tech_is_available(xpre) then
                    if science_is_available(xpre, lsci) then
                        -- Remember that we are researching towards current tech
                        set(f.index, keys.current_tech, q)

                        -- Return the prerequisite tech name
                        return pre
                    else
                        misses_science = true
                    end
                end
            end
            if misses_science then
                -- Mark that this tech misses science 
                sfsci[q] = true
            end
        end
    end
end

local get_single_next_science = function(candidates, lsci, tsx)

    local res = {
        direct = {
            spoilable = {},
            nonspoilable = {}
        },
        indirect = {
            spoilable = {},
            nonspoilable = {}
        }
    }
    for tech_name, xcur in pairs(candidates) do
        -- Check if current tech is available
        if xcur.available then
            if tech_is_available(xcur) and science_is_available(xcur, lsci) then
                if xcur.meta.has_spoilable_science then
                    res.direct.spoilable[tech_name] = xcur
                else
                    res.direct.nonspoilable[tech_name] = xcur
                end
            end
        else
            -- Go through all prerequisites and get available tech
            for pre, _ in pairs(xcur.meta.all_prerequisites or {}) do
                local xpre = tsx[pre]
                -- Check if the prerequisite is available and we have the science for it
                if xpre.available then
                    if tech_is_available(xpre) and science_is_available(xpre, lsci) then
                        -- Add it to the appropriate candidate list
                        if xpre.meta.has_spoilable_science then
                            res.indirect.spoilable[pre] = xpre
                        else
                            res.indirect.nonspoilable[pre] = xpre
                        end
                    end
                end
            end
        end
    end

    -- Return either the first spoilable or first nonspoilable candidate
    local first = {"direct", "indirect"}
    local second = {"spoilable", "nonspoilable"}
    for _, frst in pairs(first) do
        for _, sec in pairs(second) do
            local k, v = next(res[frst][sec])
            if k then
                return k
            end
        end
    end
end
local get_next_science_smart = function(f)
    -- This function gets the first next science which is required to auto research
    -- We first look if we can research towards any essential science
    -- Then we look if we can research towards any trigger tech
    -- Then we look if we can start any science at all
    -- For each phase, we will look at all the technology that is available for research
    -- For each available research we first check if we have all the required science packs
    -- If any of the remaining research requires a spoilable science, we try to queue that one first
    local tsx = tech.get_all_tech_state_ext(f.index)
    local lsci = lab.get_labs_fill_rate(f.index)
    local essential, trigger, available, has_spoilable = {}, {}, {}, {}
    local nexttech

    -- Populate initial arrays
    for tech_name, xcur in pairs(tsx) do
        -- Only unresearched and enabled non-infinite tech
        if not xcur.technology.researched and xcur.technology.enabled and not xcur.meta.hidden and
            not xcur.meta.is_infinte then
            if xcur.available then
                available[tech_name] = xcur
            end
            if xcur.meta.prototype.essential then
                essential[tech_name] = xcur
            end
            if xcur.meta.has_trigger then
                trigger[tech_name] = xcur
            end
            if xcur.meta.has_spoilable_science then
                has_spoilable[tech_name] = xcur
            end
        end
    end

    -- Step 1: Get next sciences for essential tech
    nexttech = get_single_next_science(essential, lsci, tsx)
    if nexttech then
        return nexttech
    end

    -- Step 2: Get next science for trigger tech
    nexttech = get_single_next_science(trigger, lsci, tsx)
    if nexttech then
        return nexttech
    end

    -- Step 3: Get any available tech
    nexttech = get_single_next_science(available, lsci, tsx)
    if nexttech then
        return nexttech
    end
end

local get_queue_position = function(f, tech_name)
    -- Check if technology is valid or early exit
    local t = f.technologies[tech_name] or nil
    if not t or not t.valid then
        return
    end

    -- Get the queued tech index
    local sfq = get(f.index, keys.queue)
    for i, q in pairs(sfq or {}) do
        if q == tech_name then
            return i
        end
    end
end

local get_queue_length = function(f)
    -- Init the queue and get the global force
    local sfq = get(f.index, keys.queue)

    -- Return the queue length, or 0 if the queue array does not exist
    return #sfq or 0
end

queue.get_tech_missing_science = function(force_index)
    return get(force_index, keys.misses_science)
end
queue.get_current_researching = function(force_index)
    return get(force_index, keys.current_tech)
end

---------------------------------------------------------------------------
-- Ingame queue interactions
---------------------------------------------------------------------------

queue.sync_ingame_queue = function(f)
    local sfq = get(f.index, keys.queue)
    if not sfq then
        return
    end
    if not f.research_queue or next(f.research_queue) == nil or #f.research_queue == 0 then
        return
    end

    -- If there is only one item in the research queue check if it is our first next tech
    if #f.research_queue == 1 then
        local next = get_first_next_tech(f)
        if f.research_queue[1].name == next then
            return
        end
    end

    -- Remove all tech from our queue (if applicable) and add it again
    for _, t in pairs(f.research_queue) do
        queue.remove(f, t.name, true)
    end
    for i = #f.research_queue, 1, -1 do
        queue.add(f, f.research_queue[i].name, 1, true)
    end

    -- If we don't have anything in our queue but there is an in-game queue, add all tech
    if #sfq == 0 and f.research_queue and next(f.research_queue) ~= nil then
        for _, t in pairs(f.research_queue) do
            queue.add(f, t.name)
        end
        return
    end
    -- -- This function syncs the ingame queue towards the modqueue

    -- -- Get some variables to work with
    -- local sfq = get_queue(force.index)

    -- -- Early exit if there is nothing in the in-game queue because there is nothing to update
    -- if #force.research_queue == 0 then
    --     return
    -- end

    -- -- Early exit if the ingame queue is 1 and
    -- if #force.research_queue == 1 then
    --     local first = get_first_next_tech(force)
    --     if first == force.research_queue[1].name then
    --         return
    --     end
    -- end

    -- -- Create the array of technology that we need to add to our mods queue
    -- local iq = 1
    -- local add = {}
    -- for it, t in pairs(force.research_queue) do
    --     -- If we are at the start of both arrays we can check if the in-game queued technology is an entry node for the first technology in our mods queue
    --     local ispre = false
    --     if #sfq > 0 then
    --         if iq == 1 and it == 1 and sfq[1] then
    --             ispre = util.array_has_value(sfq[1].metadata.entry_nodes or {}, t.name)
    --         end
    --     end

    --     -- Check if the technology in the in-game queue matches our queue at the current positions
    --     -- If they are equal increase the index for our mods queue
    --     -- If they are not equal we need to add (move) the technology in our mods queue to the correct position
    --     -- if scheduler.get_queue_position(force, t.name) == it or ispre then
    --     if #sfq > 0 and iq <= #sfq and sfq[iq] and sfq[iq].technology_name == t.name then
    --         iq = iq + 1
    --     elseif ispre then -- Remove the entry node from the in-game queue
    --         force.cancel_current_research()
    --     else
    --         local prop = {
    --             pos = iq,
    --             name = t.name
    --         }
    --         table.insert(add, prop)
    --     end
    -- end

    -- -- Kick out all in-game queued tech from our queue
    -- for _, t in pairs(add) do
    --     queue.remove(force, t.name, true)
    -- end

    -- -- Add each research to our queue
    -- for i = #add, 1, -1 do
    --     local t = add[i]
    --     queue.add(force, t.name, t.pos)
    -- end

    -- -- Start next research if the in-game queue is empty
    -- if #force.research_queue == 0 then
    --     queue.start_next_research(force)
    -- end

    -- -- If anything changed we also need to update the GUI
    -- state.request_gui_update(force)
end

-- This function requeues finished technology when applicable
---@param f LuaForce
---@param t LuaTechnology
queue.requeue_finished = function(f, t)
    local xcur = tech.get_single_tech_state_ext(f.index, t.name)
    if not xcur then
        f.print("[RQM] Error: Unexpected technology " .. (t.name or "(no technology passed)"))
        return
    end

    -- For finite tech levels that are not fully researched yet we only need to request the next stage
    if xcur.technology.level and not xcur.meta.is_infinite and not xcur.technology.researched then
        return
    end

    -- For all other cases we have to remove the tech from the queue
    queue.remove(f, t.name, true)

    -- If it is an infinite tech and requeueing is enabled we have to add it to the end of the queue again
    if xcur.meta.is_infinite and
        state.get_force_setting(f.index, "requeue_infinite_tech",
            const.default_settings.force.settings.requeue_infinite_tech) then
        queue.add(f, tech.name)
    end
end

queue.start_next_research = function(f)
    -- This function queues the first next research from our mod queue and clears any subsequent ingamequeued tech
    -- Early exit if no force
    if not f then
        return
    end

    -- Early exit if RQM is disabled
    local st = state.get_force_setting(f.index, "master_enable")
    if st == "left" then
        f.research_queue = nil
        return
    end

    -- Early exit and clear queue if we don't have a queue and auto research is not enabled
    local sfq = get(f.index, keys.queue)
    local auto_research = state.get_force_setting(f.index, "auto_research",
        const.default_settings.force.settings.auto_research)
    if (not sfq or #sfq == 0) and not auto_research then
        f.research_queue = nil
        return
    end
    -- Early exit if we have exactly 1 item in the queue and auto research is enabled
    if sfq and #sfq == 1 and auto_research then
        return
    end

    -- Queue the next research
    local next = get_first_next_tech(f)
    if next and f.research_queue then
        -- Queue the first next technology
        if (#f.research_queue == 1 and f.research_queue[1] ~= next) or #f.research_queue ~= 1 then
            f.research_queue = {next}
        end

        -- Reset flags
        set(f.index, keys.announced_blocked, nil)
    else
        -- Check if we have auto research enabled
        if state.get_force_setting(f.index, "auto_research", const.default_settings.force.settings.auto_research) then
            next = get_next_science_smart(f)
            if next then
                if (#f.research_queue == 1 and f.research_queue[1] ~= next) or #f.research_queue ~= 1 then
                    f.research_queue = {next}
                end
                set(f.index, keys.announced_blocked, nil)
            else
                if not get(f.index, keys.announced_blocked) then
                    f.print("[RQM] - Unable to AI auto queue any next research")
                    set(f.index, keys.announced_blocked, true)
                    f.research_queue = nil
                end
            end
        else
            -- Notify user because we are unable to queue anything
            if not get(f.index, keys.announced_blocked) then
                f.print("[RQM] - Unable to queue next research because preconditions are not met")
                set(f.index, keys.announced_blocked, true)
                f.research_queue = nil
            end
        end
    end

end

queue.is_research_stuck = function(f)
    local sfq = get(f.index, keys.queue)
    local cur = get(f.index, keys.current_tech)

    if not sfq or #sfq == 0 then
        -- If we have nothing in our queue we're not stuck
        return false
    else
        -- We have something in the queue
        -- So if we are not researching towards a tech it means we are stuck
        return cur == nil
    end
end

---------------------------------------------------------------------------
-- Queue manipulation
---------------------------------------------------------------------------

---@param f LuaForce
---@param tech_name string technology name
---@param pos? int position
---@param silent? bool announce or not
queue.add = function(f, tech_name, pos, silent)
    if not tech_name then
        return
    end
    -- This function adds a new technology to the modqueue
    -- If no position is given assume append at the end
    -- Check if technology is valid or early exit
    local t = f.technologies[tech_name]
    if not t or not t.valid then
        if t.name and (t.name ~= nil or t.name ~= "") then
            f.print("[RQM] ERROR: Trying to queue technology: '" .. t.name ..
                        "' but it is not valid, please open a bug report on the mod portal")
        else
            f.print("[RQM] ERROR: Trying to queue technology: '" .. serpent.line(t) ..
                        "' but it is not valid, please open a bug report on the mod portal")
        end
        return
    end

    -- Check if this research is actually available or early exit
    if not t.enabled then
        if not silent then
            f.print({"rqm-msg.warn-queue-disabled", t.localised_name})
        end
        return
    end

    local sfq = get(f.index, keys.queue)

    -- Eary exit if this technology is already scheduled
    for _, q in pairs(sfq or {}) do
        if q == t.name then
            -- TODO: If the user adds an infinite tech multiple times to the in-game queue we need to trigger the auto clean-up
            local t = f.technologies[q]
            if not silent then
                f.print({"rqm-msg.already-queued", t.localised_name})
            end
            return
        end
    end

    -- Add the tech to our queue
    if pos then
        table.insert(sfq, pos, tech_name)
    else
        table.insert(sfq, tech_name)
    end

    -- Register queued
    tech.update_queued(f.index, tech_name, true)

    if not silent then
        -- Request next research
        state.request_next_research(f)

        -- Announce
        f.print({"rqm-msg.added-to-queue", t.localised_name})
    end
end

---@param f LuaForce
---@param tech_name string technology name
---@param silent? bool position
queue.remove = function(f, tech_name, silent)
    -- This function removes a technology from the modqueue

    -- Go through our queue and drop the target tech
    local sfq = get(f.index, keys.queue)
    for i, q in pairs(sfq or {}) do
        if q == tech_name then
            -- We found our target tech, remove it from our queue
            table.remove(sfq, i)

            -- Deregister queued
            tech.update_queued(f.index, tech_name, false)

            if not silent then
                -- Request next research
                state.request_next_research(f)

                -- Announce
                local t = f.technologies[q]
                f.print({"rqm-msg.removed-from-queue", t.localised_name})
            end

            -- Exit because there is nothing more to do
            return
        end
        i = i + 1
    end

end

local move_research = function(f, tech_name, old_position, new_position)
    -- Early exit if same position
    if old_position == new_position then
        return
    end

    -- Get the queue
    local gfq = get(f.index, keys.queue)
    if not gfq then
        return
    end

    -- Remove the old position
    table.remove(gfq, old_position)

    -- Insert the item on the new position
    table.insert(gfq, new_position, tech_name)

    -- Request next research
    state.request_next_research(f)

end

queue.promote = function(f, tech_name, steps)
    -- Check if technology is valid or early exit
    local t = f.technologies[tech_name] or nil
    if not t or not t.valid then
        return
    end

    -- Get the current position or early exit if already first
    local i = get_queue_position(f, tech_name)
    if i == 1 then
        return
    end

    -- Calculate new position
    local new_position
    if i - steps < 1 then
        new_position = 1
    else
        new_position = i - steps
    end

    move_research(f, tech_name, i, new_position)
end

queue.demote = function(f, tech_name, steps)
    -- Check if technology is valid or early exit
    local t = f.technologies[tech_name] or nil
    if not t or not t.valid then
        return
    end

    -- Get the current index and length or early exit if already last
    local i = get_queue_position(f, tech_name)
    local l = get_queue_length(f)
    if i == l then
        return
    end

    -- Calculate new position
    local new_position
    if i + steps > l then
        new_position = l
    else
        new_position = i + steps
    end

    -- Do the move
    move_research(f, tech_name, i, new_position or i + 1)
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
    local sfq = get(f.index, keys.queue)
    if not sfq then
        return
    end
    if not f.research_queue or next(f.research_queue) == nil or #f.research_queue <= 1 then
        return
    end

    -- -- Remove all tech from our queue (if applicable) and add it again
    -- for _, t in pairs(f.research_queue) do
    --     queue.remove(f, t.name, true)
    -- end
    -- for i = #f.research_queue, 1, -1 do
    --     queue.add(f, f.research_queue[i].name, 1, true)
    -- end
    queue.start_next_research(f)
end

queue.clear = function(f)
    -- This function clears the ingame queue
    local sfq = get(f.index, keys.queue)
    if not sfq then
        return
    end
    for i = #sfq, 1, -1 do
        queue.remove(f, sfq[i].technology_name)
    end

    -- Clear force ingame queue and request GUI update
    f.research_queue = {}
    state.request_gui_update(f)
end

---------------------------------------------------------------------------
-- Interfaces
---------------------------------------------------------------------------
queue.get_queue = function(force_index)
    return get(force_index, keys.queue)
end

---------------------------------------------------------------------------
-- Init
---------------------------------------------------------------------------

queue.init_force = function(force_index)
    local sf = storage.forces[force_index]
    if not sf.queue then
        sf.queue = {}
    end
    local sq = sf.queue

    -- Init the queue
    if not sq[keys.queue] then
        sq[keys.queue] = {}
    end

    -- Register each queued tech
    local sfq = get(force_index, keys.queue)
    for _, q in pairs(sfq or {}) do
        tech.update_queued(force_index, q, true)
    end
end

return queue
