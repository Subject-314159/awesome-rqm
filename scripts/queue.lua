--- The queue module is the model in which the mod queue is stored
local state = require("lib.state")
local util = require("lib.util")
local const = require("lib.const")
-- local analyzer = require("lib.analyzer")

local queue = {}

local get_queue = function(force_index)
    return storage.queue.forces[force_index]
end

queue.init_force = function(force_index)
    if not storage.queue.forces[force_index] then
        storage.queue.forces[force_index] = {}
    end
    local sqf = storage.queue.forces[force_index]
end
local cleanup = function(force_index)
    -- It can be that mods are removed from a save while their tech is still in the queue
    -- So we have to deregister and remove it
    local queue = get_queue(force_index)
    for i = #queue, 1, -1 do
        if not queue[i].technology or not queue[i].technology.valid then
            state.deregister_queued(force_index, queue[i].technology_name)
            queue[i] = nil
        end
    end
end

queue.init = function()
    if not storage then storage = {} end
    if not storage.queue then storage.queue = {} end
    if not storage.queue.forces then storage.queue.forces = {} end
    
    for _, f in pairs(game.forces) do
        queue.init_force(f.index)
        cleanup(f.index)
        queue.recalculate(f)
    end
end

queue.sync_ingame_queue = function(force)
    -- TODO: Rewrite
    -- This function syncs the ingame queue towards the modqueue

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

queue.requeue_finished = function(force, tech)
    -- This function requeues finished technology when applicable
    local is_infinite = state.tech_is_infinite(tech.name)

    -- For finite tech levels that are not fully researched yet we only need to request the next stage
    if tech.level and not is_infinite and not tech.researched then
        return
    end

    -- For all other cases we have to remove the tech from the queue
    queue.remove(force, tech.name, true)

    -- If it is an infinite tech and requeueing is enabled we have to add it to the end of the queue again
    if is_infinite and state.get_force_setting(force.index, "requeue_infinite_tech",
        const.default_settings.force.settings.requeue_infinite_tech) then
        queue.add(force, tech.name)
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

    -- Get queue or early exit if none
    local queue = state.get_queue(f.index)
    if not queue or #queue == 0 then return end

    -- Queue the next research
    local next = analyzer.get_first_next_tech(force)
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

---@param f LuaForce
---@param tech_name string technology name
---@param pos int position
queue.add = function(f, tech_name, pos)
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
        return
    end

    local queue = state.get_queue(f.index)

    -- Eary exit if this technology is already scheduled
    for _, q in pairs(queue or {}) do
        if q == t.name then
            f.print({"rqm-msg.already-queued", f.technologies[q].localised_name})
            return
        end
    end

    -- Add the tech to our queue & announce
    if state.add_research(f.index, tech_name, pos)
        f.print({"rqm-msg.added-to-queue", t.localised_name})
    end

    -- Request updates
    state.request_next_research(f)
    state.request_gui_update(f)
end

queue.remove = function(f, tech_name, silent)
    if state.remove_research(f.index, tech_name) then
        -- Announce
        if not silent then
            f.print({"rqm-msg.removed-from-queue", q.technology.localised_name})
        end

        -- Request updates
        state.request_next_research(f)
        state.request_gui_update(f)
    end
end

local get_queue_position = function(f, tech_name)
    -- Check if technology is valid or early exit
    local t = f.technologies[tech_name] or nil
    if not t or not t.valid then
        return
    end

    -- Get the queued tech index
    local queue = state.get_queue(f.index)
    if not queue then
        return
    end
    for i, q in pairs(queue) do
        if q == tech_name then
            return i
        end
    end
end

local get_queue_length = function(f)
    -- Init the queue and get the global force
    local sfq = state.get_queue(f.index)

    -- Return the queue length, or 0 if the queue array does not exist
    return #sfq or 0
end

local move_research = function(force, tech_name, old_position, new_position)
    -- Early exit if same position
    if old_position == new_position then
        return
    end

    -- Remove and add the tech
    state.remove_research(f.index, tech_name)
    state.add_research(f.index, tech_name, new_position)

    -- Request updates
    state.request_next_research(force)
    state.request_gui_update(force)
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

    -- Do the move
    move_research(force, tech_name, i, new_position)
end

queue.demote = function(force, tech_name, steps)
    -- Check if technology is valid or early exit
    local t = force.technologies[tech_name] or nil
    if not t or not t.valid then
        return
    end

    -- Get the current index and length or early exit if already last
    local i = get_queue_position(force, tech_name)
    local l = get_queue_length(force)
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
    move_research(force, tech_name, i, new_position or i + 1)
end

queue.clear = function(f)
    -- This function clears the ingame queue
    local queue = state.get_queue(f.index)
    if not queue then
        return
    end
    for i = #queue, 1, -1 do
        state.remove_research(f.index, queue[i])
    end

    -- Clear force ingame queue and request GUI update
    f.research_queue = {}
    state.request_gui_update(f)
end

return queue
