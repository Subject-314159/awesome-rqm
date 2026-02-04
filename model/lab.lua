local util = require("lib.util")

local lab = {}

local globkeys = {
    all_forces = "all_forces",
    current_lab_idx = "current_lab_idx",
    current_force_idx = "current_force_idx"
}
local setglob = function(key, val)
    storage.lab[key] = val
end
local getglob = function(key)
    return storage.lab[key]
end

local keys = {
    all_labs = "all_labs",
    lab_content = "lab_content"
}
local set = function(force_index, key, val)
    storage.forces[force_index].lab[key] = val
end
local get = function(force_index, key)
    if not storage.forces[force_index] then
        return
    end
    return storage.forces[force_index].lab[key]
end

-- Data model
-- storage.lab = {
--     ["current_lab_idx"] = bool,
--     ["current_force_idx"] = bool
-- }
-- storage.forces[force_index].lab = {
--     ["all_labs"] = {unit_number, ...},
--     ["lab_content"] = {
--         [unit_number] = {
--             [lab] = LuaEntity
--             [all_ticks] = {game.tick, ...}
--             [game.tick] = {["science-1"] = int, ...},
--             ...
--         }
--     }
-- }

lab.tick_update = function()
    -- This function is a staggering update with a rate limit of 100 labs (currently hard coded)
    -- Go through all the labs for each force, read their content sciences, move on to the next force

    local all_forces = getglob(globkeys.all_forces)
    local current_force_idx = getglob(globkeys.current_force_idx)
    local current_lab_idx = getglob(globkeys.current_lab_idx)

    -- Early exit if no forces registered yet
    if #all_forces == 0 then
        return
    end

    -- Forward declare & const
    local inv, lcur, tcur, force_index, sal, slc, lab_id, lab
    local max_time = 10 * 60 -- 10 sec
    local max_len = 100 -- 11 minutes at 1x/42 ticks

    -- Kick off the loop
    local count = 0
    while count < 100 do -- TODO: Make this a mod setting
        -- Reset the current force index
        if current_force_idx == 0 then
            current_force_idx = #all_forces
        end
        force_index = all_forces[current_force_idx]

        -- Get labs for this force or skip if there are no labs
        sal = get(force_index, keys.all_labs)
        slc = get(force_index, keys.lab_content)
        if #sal == 0 then
            goto next_lab
        end

        -- Reset current lab index
        if current_lab_idx == 0 then
            current_lab_idx = #sal
        end

        -- Get the lab entity
        lab_id = sal[current_lab_idx]
        lcur = slc[lab_id]
        lab = lcur.lab

        -- Remove & skip this lab if it no longer exists
        if not lab or not lab.valid then
            table.remove(sal, current_lab_idx)
            slc[lab_id] = nil
            goto next_lab
        end

        -- Get the science inventory or skip if no inventory
        inv = lab.get_inventory(defines.inventory.lab_input)
        if not inv then
            goto next_lab
        end

        -- Init the current tick content array
        if not lcur[game.tick] then
            lcur[game.tick] = {}
        end
        tcur = lcur[game.tick]

        -- Read the lab content
        for _, c in pairs(inv.get_contents()) do
            tcur[c.name] = (tcur[c.name] or 0) + (c.count or 0)
        end

        -- Remember the tick and clean up old ones
        if not lcur.all_ticks then
            lcur.all_ticks = {}
        end
        table.insert(lcur.all_ticks, game.tick)
        for i = #lcur.all_ticks, 1, -1 do
            -- game.print("lab " .. lab.unit_number .. " tick " .. lcur.all_ticks[i])
            if i <= (#lcur.all_ticks - max_len) or lcur.all_ticks[i] < (game.tick - max_time) then
                lcur[lcur.all_ticks[i]] = nil
                table.remove(lcur.all_ticks, i)
            end
        end

        ::next_lab::

        -- Update rate limiter counter
        count = count + 1

        -- Set the index for next lab
        current_lab_idx = current_lab_idx - 1

        -- Set next force index if we had all labs in current force
        if current_lab_idx <= 0 then
            -- Get the next force
            current_force_idx = current_force_idx - 1
            current_lab_idx = 0
        end

        -- Early exit if we ran through everything before we hit the rate limit
        if current_force_idx == 0 then
            break
        end
    end
end

lab.get_labs_fill_rate = function(force_index)
    -- We need to figure out how well any science is filled in the labs
    -- It can be that 1 lab has 100 sciences, or 100 labs each 1 science
    -- The latter is more favorable
    local slc = get(force_index, keys.lab_content)
    local any_sciences = {} -- Array with sciences which have been seen at least once
    local science_total = {} -- Cummulative count of total # of sciences in all labs
    local science_present = {} -- How many ticks a science has been in any lab
    local tick_count = 0
    local science_concat_lab_count = {}

    -- The grand total science item count over time in all labs
    local science_grand_total = {}

    -- The total number of labs for each science we consider to be sufficiently filled
    local science_present_in_labs = {}
    local total_labs = 0

    -- The total number of times a science has been registered in any lab
    local science_present_total_count = {}
    local total_count = 0

    -- Go through each lab
    for lab_id, lcur in pairs(slc or {}) do
        -- Skip if this lab has not been registering any ticks
        if not lcur or not lcur.all_ticks or #lcur.all_ticks == 0 then
            goto continue
        end

        -- Count each tick a science is present in this lab and count the total nr of sciences in this lab over time
        local lab_science_present_tick_count = {}
        local lab_science_item_count = {}
        local lab_tick_count = 0
        for _, tick in pairs(lcur.all_ticks or {}) do
            for science, count in pairs(lcur[tick] or {}) do
                lab_science_present_tick_count[science] = (lab_science_present_tick_count[science] or 0) + 1
                lab_science_item_count[science] = (lab_science_item_count[science] or 0) + count
            end
            lab_tick_count = lab_tick_count + 1
        end

        -- Skip this lab if it has no sciences at all or we don't have any tick content
        if next(lab_science_present_tick_count) == nil or lab_tick_count == 0 then
            goto continue
        end

        -- Process the tick counts
        local threshold = 50
        total_labs = total_labs + 1
        local scistr = "||"
        local allsci = {}
        for science, count in pairs(lab_science_present_tick_count) do
            -- Count this lab if it has the science for a sufficient time
            if ((count * 100) / lab_tick_count) > threshold then
                science_present_in_labs[science] = (science_present_in_labs[science] or 0) + 1
            end

            -- Add to the total number of ticks this science was present in any lab
            science_present_total_count[science] = (science_present_total_count[science] or 0) + 1
            -- total_count = total_count + 1

            -- Grand total of this science
            science_grand_total[science] = (science_grand_total[science] or 0) + (count or 0)

            -- All sciences per lab
            scistr = scistr .. science .. "||"
            table.insert(allsci, science)
        end
        if not science_concat_lab_count[scistr] then
            science_concat_lab_count[scistr] = {}
        end
        science_concat_lab_count[scistr].cnt = (science_concat_lab_count[scistr].cnt or 0) + 1
        science_concat_lab_count[scistr].sciences = allsci

        ::continue::
    end

    -- Calculate the fill rate for each science
    -- Register rate is how many labs out of the total labs have seen this science at least once in the registered ticks
    -- Fill rate is how many labs we consider to be filled, i.e. the science is present in enough ticks
    local science_lab_register_rate = {}
    if total_labs > 0 then
        for science, count in pairs(science_present_in_labs) do
            science_lab_register_rate[science] = (count * 100) / total_labs
        end
    end
    local science_lab_fill_rate = {}
    if total_labs > 0 then
        for science, count in pairs(science_present_total_count) do
            science_lab_fill_rate[science] = (count * 100) / total_labs
        end
    end

    -- Calculate the grand total rate
    -- This calculation feels a bit skewed, because the science with the highest total count will be the 100% reference
    -- A science that was filled in the last few ticks does not yet have the opportunity to account for enough fill rate
    local science_grand_total_rate = {}
    local max_count = 0
    for science, count in pairs(science_grand_total) do
        if count > max_count then
            max_count = count
        end
    end
    if max_count > 0 then
        for science, count in pairs(science_grand_total) do
            science_grand_total_rate[science] = (count * 100) / max_count
        end
    end

    -- The return array
    local res = {
        science_lab_register_rate = science_lab_register_rate,
        science_lab_fill_rate = science_lab_fill_rate,
        science_grand_total_rate = science_grand_total_rate,
        science_concat_lab_count = science_concat_lab_count
    }

    -- FOR DEBUGGING
    -- log(serpent.block(res))

    -- return science_lab_register_rate
    return science_lab_fill_rate
    -- return res
end

---@param entity LuaEntity
lab.register = function(entity)
    if not entity then
        return
    end

    -- Add the ID to the overall array
    local sal = get(entity.force.index, keys.all_labs)
    local lab_id = entity.unit_number
    if not util.array_has_value(sal, lab_id) then
        table.insert(sal, lab_id)
    end

    -- Create data array for this lab
    local slc = get(entity.force.index, keys.lab_content)
    if not slc[lab_id] then
        slc[lab_id] = {
            lab = entity
        }
    end
end

lab.init_force = function(force_index)
    -- Get lab
    local all_forces = getglob(globkeys.all_forces)

    -- Add unique force index to all forces array
    if not util.array_has_value(all_forces, force_index) then
        table.insert(all_forces, force_index)
    end

    -- Init forces.module
    if not storage.forces[force_index].lab then
        storage.forces[force_index].lab = {}
    end
    local sfl = storage.forces[force_index].lab

    -- Init keys
    if not sfl[keys.all_labs] then
        sfl[keys.all_labs] = {}
    end
    if not sfl[keys.lab_content] then
        sfl[keys.lab_content] = {}
    end

    -- Init the labs
    for _, s in pairs(game.surfaces) do
        -- Find all labs on this surface belonging to this force
        local labs = s.find_entities_filtered({
            type = "lab",
            force = force_index
        })
        -- Register each lab
        for _, l in pairs(labs) do
            lab.register(l)
        end
    end
end

lab.init = function()
    -- Init module
    if not storage.lab then
        storage.lab = {}
    end
    -- local sa = storage.lab
    -- if not sa.all_forces then
    --     sa.all_forces = {}
    -- end

    -- Init keys
    setglob(globkeys.all_forces, {})
    setglob(globkeys.current_force_idx, 0)
    setglob(globkeys.current_lab_idx, 0)
end

return lab
