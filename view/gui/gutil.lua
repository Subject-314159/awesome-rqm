-- GUI related utilities
local state = require("model.state")
local gutil = {}

gutil.disenable_recursive = function(elm, enbl)
    if not elm then
        return
    end
    -- Ignore this element if it has the ignore_force_enable tag, i.e.;
    -- Process this element if it does not have tags,
    -- or if it does have tags but not ignore_force_enable
    if not elm.tags or not elm.tags.ignore_force_enable then
        elm.enabled = enbl
    end
    for _, c in pairs(elm.children or {}) do
        if not elm.tags.ignore_enable then
            gutil.disenable_recursive(c, enbl)
        end
    end
end

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

gutil.get_tech_name = function(player_index, xcur)

    local name = state.get_translation(player_index, "technology", xcur.technology.name, "localised_name")
    if xcur.technology.level then
        -- Only add the level if the name string does not end in a number
        if xcur.technology.level > 1 and not (type(name) == "string" and name:match("%d$") ~= nil) then
            name = name .. " " .. xcur.technology.level
        end

        -- Add (infinite) if applicable
        if xcur.meta.is_infinite then
            name = name .. " (infinite)"
        end
    end
    return name
end

return gutil
