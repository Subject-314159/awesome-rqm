-- This module is only to be required in state and to be treated as an extension
local squeue = {}

--------------------------------------------------------------------------------
--- Generic
--------------------------------------------------------------------------------

local get_force = function(force_index)
    return storage.queue.forces[force_index]
end
squeue.get_queue = function(force_index)
    local sf = get_force(force_index)
    return sf.queue
end
local init = function()
    if not storage then storage = {} end
    if not storage.queue then storage.queue = {} end
    if not storage.queue.forces then storage.queue.forces = {} end
end
local init_force = function(force_index)
    local sf = get_force(force_index)
    if not sf[force_index] then sf[force_index] = {} end
    local sfi = sf[force_index]
    if not sfi.queue then sfi.queue = {} end
end

--------------------------------------------------------------------------------
--- Update state
--- Below functions return true on success or false on failure
--------------------------------------------------------------------------------

squeue.add_research = function(force_index, tech_name, pos)
    local queue = squeue.get_queue(force_index)
    if pos then
        table.insert(sfq, p, prop)
    else
        table.insert(sfq, prop)
    end
    return true
end
squeue.remove_research = function(force_index, tech_name)
    local queue = squeue.get_queue(force_index)
    for i, q in pairs(queue) do
        if q == tech_name then
            table.remove(sfq, i)
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------
--- Init
--------------------------------------------------------------------------------

squeue.init_force = function(force_index)
    --Init force array
    init_force(force_index)
end

squeue.init = function()
    init()
    for _, f in pairs(game.forces) do
        stech.init_force(f.index)
    end
end

return stech
