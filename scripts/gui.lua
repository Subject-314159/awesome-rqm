local gui = {}

local const = require('const')
local skeleton = require('gui-skeleton')
local content = require('gui-content')
local target = "screen"

local open = function(player_index, anchor)
    -- Build the skeleton
    skeleton.build(player_index, anchor)

    -- Repopulate the content
    content.repopulate_all(player_index, anchor)

end

local close = function(player_index, anchor)
    anchor["rqm_gui"].destroy()
end

gui.get = function(player_index)
    local player = game.get_player(player_index)
    if not player then
        return
    end
    local main = player.gui[target]["rqm_gui"]
    return main
end

gui.is_open = function(player_index)
    return (gui.get(player_index) ~= nil)
end

gui.toggle = function(player_index)
    local player = game.get_player(player_index)
    if not player then
        return
    end

    if gui.is_open(player_index) then
        close(player_index, player.gui[target])
    else
        open(player_index, player.gui[target])
    end
end

gui.is_search_focussed = function(player_index)
    -- local p = game.get_player(player_index)
    -- local anchor = p.gui[target]
    -- local main = anchor["rqm_gui"]

    -- if main then
    --     local src = skeleton.get_child(anchor, "search_textfield")
    --     if src then

    --     else
    --         return false
    --     end
    -- else
    --     return false
    -- end
end

gui.focus_search = function(player_index)
    -- Remember settings
    local p = game.get_player(player_index)
    local anchor = p.gui[target]
    local main = anchor["rqm_gui"]

    if main then
        -- local src = main.right.science_bottom.available_sciences.search
        local src = skeleton.get_child(anchor, "search_textfield")
        if src then
            game.print("We have a search field")
            src.focus()
            src.select(1, 0)
        else
            game.print("Search field not found")
        end
    else
        game.print("There is no main GUI")
    end
end

gui.repopulate_open = function()
    for _, p in pairs(game.players) do
        if p.opened and p.opened.name == "rqm_gui" then
            local anchor = p.gui[target]
            content.repopulate_all(p.index, anchor)
        end
    end
end

gui.update_search_field = function(player_index)
    local p = game.get_player(player_index)
    local anchor = p.gui[target]
    local main = anchor["rqm_gui"]

    if main then
        content.repopulate_tech(player_index, anchor)
    else
        game.print("There is no main GUI")
    end
end
return gui
