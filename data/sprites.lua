-- Small = 16px, medium = 32px, large = 64px
local p = "__awesome-rqm__/graphics/icons/"

local get_sprite = function(name, w, h)
    local prop = {
        type = "sprite",
        name = "rqm_" .. name,
        filename = p .. name .. ".png",
        priority = "extra-high-no-scale",
        width = w,
        height = h
    }
    return prop
end

-- Small sprites
data:extend({get_sprite("bin_small", 16, 16), get_sprite("bookmark_small", 12, 15),
             get_sprite("blacklist_small", 16, 16), get_sprite("arrow_down_small", 14, 10),
             get_sprite("arrow_down_small_black", 14, 10), get_sprite("arrow_up_small", 14, 10),
             get_sprite("arrow_up_small_black", 14, 10)})

-- Medium sprites
data:extend({get_sprite("queue_medium", 26, 26), get_sprite("blocked_medium", 26, 26),
             get_sprite("progress_medium", 32, 31), get_sprite("inherit_medium", 32, 32),
             get_sprite("no_science_medium", 32, 32)})

-- Large sprites
data:extend({get_sprite("bookmark_large", 46, 64), get_sprite("critical_large", 64, 61),
             get_sprite("queue_large", 49, 64), get_sprite("blacklist_large", 64, 64),
             get_sprite("settings_large", 64, 64)})
