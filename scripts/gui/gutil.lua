-- GUI related utilities
local state = require("lib.state")
local gutil = {}

local get_child_recursive
get_child_recursive = function(parent, target)
    if parent.name == target then
        return parent
    else
        for _, child in pairs(parent.children) do
            local res = get_child_recursive(child, target)
            if res then
                return res
            end
        end
    end
end
gutil.get_child = function(anchor, target)
    return get_child_recursive(anchor, target)
end

gutil.get_tech_name = function(player_index, tech)

    local name = state.get_translation(player_index, "technology", tech.name, "localised_name")
    if tech.level and tech.level > 1 then
        -- Only add the level if the name string does not end in a number
        if not (type(name) == "string" and name:match("%d$") ~= nil) then
            name = name .. " " .. tech.level
        end

        -- Add (infinite) if applicable
        local tp = state.get_environment_setting("technology_properties")
        if tp[tech.name] and tp[tech.name].is_infinite then
            name = name .. " (infinite)"
        end
    end
    return name
end

return gutil
