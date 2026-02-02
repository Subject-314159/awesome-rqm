local const = require("lib.const")
local util = require("lib.util")
local env = require("model.env")

local tech = {}

local keys = {
    state_ext = "state_extended",
    to_update = "to_update"
}

--------------------------------------------------------------------------------
--- Generic
--------------------------------------------------------------------------------

local set = function(force_index, key, val)
    storage.forces[force_index].tech[key] = val
end

local get = function(force_index, key)
    return storage.forces[force_index].tech[key]
end

local tech_is_available = function(t)
    for _, pre in pairs(t.prerequisites or {}) do
        if not pre.researched then
            return false
        end
    end
    return true
end

--------------------------------------------------------------------------------
--- Interfaces
--------------------------------------------------------------------------------

tech.get_all_tech_state_ext = function(force_index)
    return get(force_index, keys.state_ext)
end

tech.get_single_tech_state_ext = function(force_index, tech_name)
    local tsx = get(force_index, keys.state_ext)
    local xcur = tsx[tech_name] or nil
    return xcur
end

--------------------------------------------------------------------------------
--- Update
--------------------------------------------------------------------------------

tech.update_researched = function(force_index, tech_name)
    local tsx = get(force_index, keys.state_ext)
    local xcur = tsx[tech_name]

    -- Update available property of all prerequisites/successors
    if xcur.technology.researched then
        -- If the technology is researched then we need to check the successors
        for suc_name, _ in pairs(xcur.technology.successors) do
            local xsuc = tsx[suc_name]
            xsuc.available = tech_is_available(xsuc.technology)
        end

        -- Go through all successors and remove this tech as blocking/disabled
        for suc_name, _ in pairs(xcur.meta.all_successors) do
            local xsuc = tsx[suc_name]
            xsuc.blocked_by[tech_name] = nil
            xsuc.disabled_by[tech_name] = nil
        end
    else
        -- If the technology is not researched we need to check the prerequisites
        for pre_name, _ in pairs(xcur.technology.prerequisites or {}) do
            local spre = tsx[pre_name]
            spre.available = tech_is_available(spre.technology)
        end

        -- If this tech is blocking or disabled/hidden mark it as such for all its successors
        if xcur.has_trigger or not xcur.technology.enabled or xcur.meta.hidden then
            for suc_name, _ in pairs(xcur.meta.all_successors or {}) do
                local xsuc = tsx[suc_name]
                if xcur.has_trigger then
                    xsuc.blocked_by[tech_name] = true
                end
                if not xcur.technology.enabled or xcur.meta.hidden then
                    xsuc.disabled_by[tech_name] = true
                end
            end
        end
    end

end

tech.update_queued = function(force_index, tech_name, queued)
    local tsx = get(force_index, keys.state_ext)
    local xcur = tsx[tech_name]
    xcur.queued = queued
    -- Propagate inherit by to all prerequisites
    for pre_name, _ in pairs(xcur.meta.all_prerequisites) do
        local spre = tsx[pre_name]
        if not spre.technology.researched then
            if queued then
                spre.inherited_by[tech_name] = true
            else
                spre.inherited_by[tech_name] = nil
            end
        end
    end
end
--------------------------------------------------------------------------------
--- Init
--------------------------------------------------------------------------------
-- Data model
-- storage.forces[force_index].tech.state = {
--     [tech_name] = {
--         technology = LuaTechnology,
--         meta = env.meta,
--         available = bool,
--         queued = bool, --> controlled via queue.lua
--         blocked_by = {[tech_name] = bool, ...},
--         disabled_by = {[tech_name] = bool, ...},
--         inherited_by = {[tech_name] = bool, ...} --> controlled via queue.lua
--     }, {...}
-- }

local init_tech = function(force_index)
    local f = game.forces[force_index]
    local res = {}
    local meta = env.get_all_tech_meta()

    -- Initiate default tech array
    for tech_name, t in pairs(f.technologies) do
        res[tech_name] = {
            technology = t,
            meta = meta[tech_name],
            available = tech_is_available(t),
            queued = false,
            blocked_by = {},
            disabled_by = {},
            inherited_by = {}
        }
    end

    -- Update metadata
    for tech_name, xcur in pairs(res) do
        -- Skip researched tech as they are not important
        if xcur.technology.researched then
            goto continue
        end

        -- Propagate blocking tech
        if xcur.meta.has_trigger then
            for suc_name, _ in pairs(xcur.meta.all_successors) do
                -- Mark the current tech as blocked_by for the successor
                res[suc_name].blocked_by[tech_name] = true
            end
        end

        -- Propagate disabled/hidden tech
        if not xcur.technology.enabled or xcur.meta.prototype.hidden then
            for suc_name, _ in pairs(xcur.meta.all_successors) do
                -- Mark the current tech as blocked_by for the successor
                res[suc_name].disabled_by[tech_name] = true
            end
        end

        ::continue::
    end
    set(force_index, keys.state_ext, res)
end

tech.init_force = function(force_index)
    -- Init storage
    storage.forces[force_index].tech = {}
    local sft = storage.forces[force_index].tech
    for _, key in pairs(keys) do
        sft[key] = {}
    end

    -- Init the tech array
    init_tech(force_index)
end

return tech
