--- The queue module is the model in which the mod queue is stored
local state = require("lib.state")
local util = require("lib.util")
local const = require("lib.const")
local tech = require("model.tech")

local queue = {}

-- Data model
-- storage.forces[force_index].queue.queue = {"tech-1", ...}

local keys = {
    queue = "queue"
}

---------------------------------------------------------------------------
-- Internal queue helpers
---------------------------------------------------------------------------

local set = function(force_index, key, val)
    storage.forces[force_index].queue[key] = val
end
local get = function(force_index, key)
    return storage.forces[force_index].queue[key]
end

local tech_is_available = function(stech)
    return stech and not stech.technology.researched and stech.available and stech.technology.enabled and
               not stech.meta.has_trigger
end
local get_first_next_tech = function(f)
    local sfq = get(f.index, keys.queue)

    for _, q in pairs(sfq) do
        -- local t = state.get_technology(f.index, q.technology_name)
        local cstate = tech.get_single_tech_state(f.index, q)
        if tech_is_available(cstate) then
            return q
        else
            for _, p in pairs(cstate.meta.all_prerequisites or {}) do
                -- local pt = state.get_technology(f.index, p)
                local pstate = tech.get_single_tech_state(f.index, p.name)
                -- if tech_is_available(force, e) then
                if tech_is_available(pstate) then
                    return p.name
                end
            end
        end
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
    if not sfq then
        return
    end
    for i, q in pairs(sfq) do
        if q.technology.name == tech_name then
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
---------------------------------------------------------------------------
-- Ingame queue interactions
---------------------------------------------------------------------------

queue.sync_ingame_queue = function(force)
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
    -- local tp = state.get_environment_setting("technology_properties")
    local rcur = tech.get_single_tech_state(f.index, t.name)
    if not rcur then
        game.print("[RQM] Error: Unexpected technology " .. (t.name or "(no technology passed)"))
        return
    end

    -- For finite tech levels that are not fully researched yet we only need to request the next stage
    if rcur.technology.level and not rcur.meta.is_infinite and not rcur.technology.researched then
        return
    end

    -- For all other cases we have to remove the tech from the queue
    queue.remove(f, tech.name, true)

    -- If it is an infinite tech and requeueing is enabled we have to add it to the end of the queue again
    if rcur.meta.is_infinite and
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
        return
    end

    -- Early exit if we don't have a queue
    local sfq = get(f.index, keys.queue)
    if not sfq or #sfq == 0 then
        f.research_queue = nil
        return
    end

    -- Queue the next research
    local next = get_first_next_tech(f)
    if next and f.research_queue then
        -- Queue the first next technology
        if (#f.research_queue == 1 and f.research_queue[1] ~= next) or #f.research_queue ~= 1 then
            f.research_queue = {next}
        end
    else
        -- Notify user because we are unable to queue anything
        game.print("[RQM] - Unable to queue next research because preconditions are blocked")
    end

end

---------------------------------------------------------------------------
-- Queue manipulation
---------------------------------------------------------------------------

---@param f LuaForce
---@param tech_name string technology name
---@param pos? int position
queue.add = function(f, tech_name, pos)
    -- This function adds a new technology to the modqueue
    -- If no position is given assume append at the end
    -- Check if technology is valid or early exit
    local t = f.technologies[tech_name]
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

    local sfq = get(f.index, keys.queue)

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
    if pos then
        table.insert(sfq, pos, prop)
    else
        table.insert(sfq, prop)
    end

    -- Announce
    f.print({"rqm-msg.added-to-queue", t.localised_name})

    -- Register queued
    tech.update_queued(f.index, tech_name, true)

    -- Recalculate
    -- queue.recalculate(f)

    -- Request next research and gui refresh
    -- state.update_technology_queued(f.index, t.name)
    state.request_next_research(f)
    state.request_gui_update(f)
end

---@param f LuaForce
---@param tech_name string technology name
---@param silent? bool position
queue.remove = function(f, tech_name, silent)
    -- This function removes a technology from the modqueue

    -- Go through our queue and drop the target tech
    local sfq = get(f.index, keys.queue)
    for i, q in pairs(sfq or {}) do
        if q.technology.name == tech_name then
            -- We found our target tech, remove it from our queue
            table.remove(sfq, i)
            -- table.remove(simp, i)

            -- Announce
            if not silent then
                f.print({"rqm-msg.removed-from-queue", q.technology.localised_name})
            end

            -- Deregister queued
            tech.update_queued(f.index, tech_name, false)

            -- Recalculate
            -- queue.recalculate(f)

            -- Request next research and gui refresh
            -- state.update_technology_queued(f.index, tech_name)
            state.request_next_research(f)
            state.request_gui_update(f)

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

    -- Remove the old position
    table.remove(gfq, old_position)

    -- Insert the item on the new position
    table.insert(gfq, new_position, tech_name)

    -- Recalculate
    -- queue.recalculate(force)

    -- Request next research and gui refresh
    state.request_next_research(f)
    state.request_gui_update(f)

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
-- Init
---------------------------------------------------------------------------

queue.init_force = function(force_index)
    local sf = storage.forces[force_index]
    if not sf.queue then
        sf.queue = {}
    end
    local sq = sf.queue
    for _, key in pairs(keys) do
        if not sq[key] then
            sq[key] = {}
        end
    end

    -- Register each queued tech
    local sfq = get(force_index, keys.queue)
    for _, q in pairs(sfq) do
        tech.update_queued(force_index, q, true)
    end
end

queue.init = function()

end

return queue
