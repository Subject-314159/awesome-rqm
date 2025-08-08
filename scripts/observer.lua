local observer = {}

local state = require('state')
local util = require('util')
local const = require('const')

local get_global_progress = function(force, tech_name)
    local sf = util.get_global_force(force)

    if not sf.progress then
        sf.progress = {}
    end
    local sfp = sf.progress

    if not sfp[tech_name] then
        sfp[tech_name] = {}
    end
    local sfpt = sfp[tech_name]

    return sfpt
end

observer.buffer_current_progress = function(force, tech_name, tick, progress)
    -- Get the progress array from storage
    local sfpt = get_global_progress(force, tech_name)

    -- Store the progress under the new tick
    sfpt[tick] = progress

end

observer.get_average_progress_speed = function(force, tech_name)
    local sfpt = get_global_progress(force, tech_name)

    -- Calculate the average progress per tick and collect obsolete ticks
    local i, minp, maxp = 0, 0, 0
    local obsolete_ticks = {}
    local threshold = game.tick - const.default_settings.force.research_progress_average_ticks
    for tick, progress in pairs(sfpt) do
        if tick < threshold then
            obsolete_ticks[tick] = true
        else
            if progress < minp or minp == 0 then
                minp = progress
            end
            if progress > maxp then
                maxp = progress
            end
            i = i + 1
        end
    end
    local spd = (maxp - minp) / i

    -- Cleanup obsolete ticks
    for t, _ in pairs(obsolete_ticks) do
        sfpt[t] = nil
    end

    -- Return the speed
    return spd
end

observer.delete_tech_progress = function(force, tech_name)
    -- Erase the complete progress array
    local sfpt = get_global_progress(force, tech_name)
    sfpt = nil
end

return observer
