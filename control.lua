-- Classes
local gui = require('scripts/gui')
local scheduler = require('scripts/scheduler')
local state = require('scripts/state')

local init = function()
    state.init()
    scheduler.init()
end

local load = function()
    -- scheduler.load()
    -- Register custom commands
    commands.add_command("rqm_debug", "Generates debug info in the game log", function(command)
        -- Get the force
        local frc = game.get_player(command.player_index).force

        scheduler.clear_queue(frc)

        -- Add technology
        scheduler.queue_research(frc, "automobilism")
        scheduler.queue_research(frc, "oil-gathering")
        scheduler.queue_research(frc, "fluid-handling")

        -- Repopulate open GUIs
        gui.repopulate_open()

        -- Redo the translations
        state.init()
    end)

    commands.add_command("rqm_unlock", "Unlocks early tech for debugging", function(command)
        local frc = game.get_player(command.player_index).force
        local techs = {"electronics", "steam-power", "automation"}
        for _, t in pairs(techs) do
            frc.technologies[t].research_recursive()
        end
    end)
end

script.on_configuration_changed(function()
    init()
    game.print("[RQM] on config changed")
end)

script.on_init(function()
    init()
    load()
end)

script.on_load(function()
    load()
end)

script.on_event(defines.events.on_tick, function(e)
end)

-- keybinding hooks
script.on_event("rqm_toggle_gui", function(event)
    gui.toggle(event.player_index)
end)

script.on_event("rqm_focus_search", function(event)
    game.print("Focus search toggled!")
    gui.focus_search(event.player_index)
end)

-- Player events handling
script.on_event(defines.events.on_gui_closed, function(e)
    game.print("On GUI close!")
    if gui.is_open(e.player_index) then
        -- Check if the search field is focussed
        if gui.is_search_focussed(e.player_index) then
            gui.defocus_search(e.player_index)
        else
            gui.toggle(e.player_index)
        end
    end
end)

script.on_event(defines.events.on_gui_click, function(e)
    -- Early exit if the gui element doesnt have our on_click tag
    if not e.element.tags or not e.element.tags["rqm_on_click"] then
        return
    end

    local t = e.element.tags
    local h = t.handler
    local p = game.get_player(e.player_index)
    local f = p.force

    -- Repopulate flag, to be set false for specific actions
    local repopulate = true

    -- Handle action
    if h == "show_technology_screen" then
        local p = game.get_player(e.player_index)
        p.open_technology_gui(e.element.name)
        repopulate = false
    elseif h == "show_category_checkbox" then
        game.print("To be implemented: Filter technology")
    elseif h == "add_queue_top" then
        scheduler.queue_research(f, t.technology, true)
    elseif h == "add_queue_bottom" then
        scheduler.queue_research(f, t.technology)
    elseif h == "remove_from_queue" then
        scheduler.remove_from_queue(f, t.technology)
    elseif h == "toggle_allowed_science" then
        state.toggle_player_setting(p.index, "allowed_" .. t.science)
    end

    -- Refresh all open GUIs to reflect the changes
    if repopulate then
        gui.repopulate_open()
    end

end)

script.on_event(defines.events.on_gui_checked_state_changed, function(e)
    -- Early exit if the gui element doesnt have our on_click tag
    if not e.element.tags or not e.element.tags["rqm_on_state_change"] then
        return
    end

    local t = e.element.tags
    local h = t.handler
    local p = game.get_player(e.player_index)
    local f = p.force

    -- Repopulate flag, to be set false for specific actions
    local repopulate = true

    -- Handle action
    if h == "toggle_checkbox" then
        state.set_player_setting(e.player_index, t.setting_name, e.element.state)
    end

    -- Refresh all open GUIs to reflect the changes
    if repopulate then
        gui.repopulate_open()
    end

end)

script.on_event(defines.events.on_gui_text_changed, function(e)
    -- Early exit if the gui element doesnt have our on_click tag
    if not e.element.tags or not e.element.tags["rqm_on_change"] then
        return
    end

    local t = e.element.tags
    local h = t.handler
    local p = game.get_player(e.player_index)
    local f = p.force

    -- Handle action
    if h == "search_textfield" then
        gui.update_search_field(e.player_index)
    end
end)

script.on_event(defines.events.on_string_translated, function(e)
    -- game.print("Translated localised string " .. serpent.line(e.localised_string) .. " resulted in " .. e.result)
    state.store_translation(e.player_index, e.id, e.result, e.localised_string)
end)
