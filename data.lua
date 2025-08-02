require('data/style')
require('data/shortcut')
require('data/sprites')

data:extend({{
    type = "technology",
    name = "rqm-dummy-technology",
    icon = "__awesome-rqm__/graphics/icons/queue_medium.png",
    icon_size = 32,
    enabled = false,
    unit = {
        count = 1,
        ingredients = {{"automation-science-pack", 1}},
        time = 9001
    }
}})
