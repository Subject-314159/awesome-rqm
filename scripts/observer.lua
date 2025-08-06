local observer = {}

local state = require('state')
local util = require('util')
local const = require('const')

local get_global_progress = function(force, tech_name)
    local sf = util.get_global_force(force)

    local sfp = sf.progress
    if not sfp then
        sfp = {}
    end

    local sfpt = sfp[tech_name]
    if not sfpt then
        sfpt = {}
    end

    return sfpt
end

observer.buffer_current_progress = function(force, tech_name, tick, progress)
    local sfpt = get_global_progress(force, tech_name)
    sfpt[tick] = progress
end

observer.get_average_progress_speed = function(force, tech_name)
    local sfpt = get_global_progress(force, tech_name)

    -- Calculate the average progress per tick
    local i, minp, maxp = 0, 0, 0
    local obsolete_ticks = {}
    for tick, progress in pairs(sfpt) do
        if tick < game.tick - const.default_settings.force.research_progress_average_ticks then
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
    for tick, _ in pairs(obsolete_ticks) do
        sfpt[tick] = nil
    end

    return spd
end

return observer
