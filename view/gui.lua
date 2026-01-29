--- The gui module is the view
local gui = {}

local gutil = require("view.gui.gutil")
local state = require("model.state")

local builder = require("view.gui.builder")
local components = require("view.gui.components")

local target = "screen"

local open = function(player_index, anchor)
    -- Close any open windows
    local p = game.get_player(player_index)
    p.opened = nil

    -- Build the skeleton
    builder.build(player_index, anchor)

    -- Repopulate the content
    components.repopulate_all(player_index, anchor)
end

local close = function(player_index, anchor)
    -- Destroy the window
    anchor.destroy()

    -- Clear the search text
    state.clear_player_setting(player_index, "search_text")
end

gui.init_player = function(player_index)
    local p = game.get_player(player_index)
    if p.opened and p.opened.name == "rqm_gui" then
        local anchor = gui.get(p.index)
        close(p.index, anchor)
    end
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
        close(player_index, gui.get(player_index))
    else
        open(player_index, player.gui[target])
    end
end

gui.is_search_focussed = function(player_index)
    -- To be implemented
end

gui.focus_search = function(player_index)
    -- Remember settings
    local p = game.get_player(player_index)
    local anchor = gui.get(player_index)

    if anchor then
        local src = gutil.get_child(anchor, "search_textfield")
        if src then
            src.focus()
            src.select(1, 0)
        end
    end
end

gui.update_search_field = function(player_index)
    local p = game.get_player(player_index)
    local anchor = gui.get(player_index)
    local src = gutil.get_child(anchor, "search_textfield")

    if anchor then
        state.set_player_setting(player_index, "search_text", src.text)
        components.repopulate_tech(player_index, anchor)
    end
end

gui.repopulate_open = function(force_index)
    for _, p in pairs(game.players) do
        if p.force.index == force_index then
            local anchor = gui.get(p.index)
            if anchor then
                components.repopulate_all(p.index, anchor)
            end
        end
    end
end

return gui
