local state = require("lib.state")
local gui = require("scripts.gui")
local queue = require("scripts.queue")
local cmd = require("scripts.cmd")
local util = require("lib.util")

----------------------------------------------------------------------------------------------------
-- INITIALIZATION
----------------------------------------------------------------------------------------------------

local init = function()
    state.init()
    gui.init()
    queue.init()
    state.init_updates()
end

local load = function()
    cmd.register_commands()
end

script.on_configuration_changed(function()
    init()
end)

script.on_init(function()
    init()
    load()
end)

script.on_load(function()
    load()
end)

script.on_event({defines.events.on_player_created, defines.events.on_player_joined_game}, function(e)
    state.init_player(e.player_index)
end)
script.on_event({defines.events.on_force_created}, function(e)
    state.init_force(e.force.index)
    queue.init_force(e.force.index)
    state.init_force_updates(e.force.index)
end)

script.on_event(defines.events.on_string_translated, function(e)
    state.store_translation(e.player_index, e.id, e.result, e.localised_string)
end)
script.on_event({defines.events.on_force_reset, defines.events.on_forces_merged}, function(e)
    -- Do a complete reinit because these events will fuck up a ton of shit
    init()
end)

----------------------------------------------------------------------------------------------------
-- TICK
----------------------------------------------------------------------------------------------------

script.on_event(defines.events.on_tick, function(e)
    local refresh_gui = false
    for _, f in pairs(game.forces) do
        if state.tech_needs_update(f) then
            state.update_pending_technology(f.index)
            -- queue.recalculate(f)
            state.request_next_research(f) -- Includes a recalculate and GUI update
        end
        if state.queue_needs_sync(f) then
            queue.sync_ingame_queue(f)
            refresh_gui = true
        end
        if state.research_needs_next(f) then
            -- queue.recalculate(f)
            queue.start_next_research(f)
            refresh_gui = true
        end

        if state.ingame_queue_needs_cleanup(f) then
            queue.clean_ingame_queue_timeout(f)
            refresh_gui = true
        end

        if state.gui_needs_update(f) then
            -- Recalculate for this force and set the flag
            queue.recalculate(f)
            refresh_gui = true
        end

    end

    if refresh_gui then
        gui.repopulate_open()
    end
end)

----------------------------------------------------------------------------------------------------
-- RESEARCH
----------------------------------------------------------------------------------------------------

script.on_event(defines.events.on_research_finished, function(e)
    -- Use the force, luke
    local f = e.research.force
    queue.requeue_finished(f, e.research)
    state.request_technology_update(f, e.research.name)
    -- state.update_technology(f.index, e.research.name)
    -- state.request_next_research(f)
end)

script.on_event({defines.events.on_research_queued, defines.events.on_research_cancelled,
                 defines.events.on_research_moved}, function(e)
    -- When ingame research queue gets modified we need to sync that to our modqueue
    local f = e.research.force
    state.request_queue_sync(f)
end)

script.on_event(defines.events.on_research_reversed, function(e)
    -- When a tech gets reversed we need to request a next research
    -- Because the one we are researching right now might no longer be available
    local f = e.research.force

    state.request_technology_update(f, e.research.name)
    -- queue.recalculate(f)
    -- state.update_technology(f.index, e.research.name)
    -- state.request_next_research(f) -- Includes a recalculate and GUI update
end)

----------------------------------------------------------------------------------------------------
-- KEYBINDING HOOKS
----------------------------------------------------------------------------------------------------

script.on_event("rqm_toggle_gui", function(e)
    gui.toggle(e.player_index)
end)
script.on_event(defines.events.on_lua_shortcut, function(e)
    if e.prototype_name == "rqm_shortcut" then
        gui.toggle(e.player_index)
    end
end)

script.on_event("rqm_toggle_menu", function(e)
end)

script.on_event("rqm_focus_search", function(e)
    gui.focus_search(e.player_index)
end)

----------------------------------------------------------------------------------------------------
-- GUI
----------------------------------------------------------------------------------------------------

-- Player events handling
script.on_event(defines.events.on_gui_closed, function(e)
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

    -- The steps to move the tech in the queue
    local steps = 1
    if e.control then
        steps = 99999999
    elseif e.shift then
        steps = 5
    end

    -- Repopulate flag, to be set false for specific actions
    local repopulate = true

    -- Handle action
    if h == "show_technology_screen" then
        local p = game.get_player(e.player_index)
        p.open_technology_gui(e.element.name)
        repopulate = false
    elseif h == "show_category_checkbox" then
        -- TODO
    elseif h == "add_queue_top" then
        queue.add(f, t.technology, 1)
    elseif h == "add_queue_bottom" then
        queue.add(f, t.technology)
    elseif h == "remove_from_queue" then
        queue.remove(f, t.technology)
    elseif h == "toggle_allowed_science" then
        state.toggle_player_setting(p.index, "allowed_" .. t.science)
    elseif h == "promote_research" then
        queue.promote(f, t.tech_name, steps)
    elseif h == "demote_research" then
        queue.demote(f, t.tech_name, steps)
    elseif h == "all_science" then
        local sci = util.get_all_sciences()
        for _, s in pairs(sci) do
            state.set_player_setting(p.index, "allowed_" .. s, true)
        end
    elseif h == "none_science" then
        local sci = util.get_all_sciences()
        for _, s in pairs(sci) do
            state.set_player_setting(p.index, "allowed_" .. s, false)
        end
    elseif h == "invert_science" then
        local sci = util.get_all_sciences()
        for _, s in pairs(sci) do
            state.toggle_player_setting(p.index, "allowed_" .. s)
        end
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
    if h == "toggle_checkbox_player" then
        state.set_player_setting(e.player_index, t.setting_name, e.element.state)
    elseif h == "toggle_radiobutton_player" then
        state.set_player_setting(e.player_index, t.setting_name, e.element.name)
    elseif h == "toggle_checkbox_force" then
        state.set_force_setting(e.player_index, t.setting_name, e.element.state)
    end

    -- Refresh all open GUIs to reflect the changes
    if repopulate then
        gui.repopulate_open()
    end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(e)
    -- Early exit if the gui element doesnt have our on_click tag
    if not e.element.tags or not e.element.tags["rqm_on_state_change"] then
        return
    end

    local t = e.element.tags
    local h = t.handler
    local p = game.get_player(e.player_index)
    local f = p.force

    if h == "announcement_level" then
        state.set_force_setting(e.player_index, t.setting_name, e.element.selected_index)
    end
end)

script.on_event(defines.events.on_gui_switch_state_changed, function(e)
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
    if h == "master_enable" then
        state.set_force_setting(f.index, "master_enable", e.element.switch_state)
        state.request_next_research(f) -- Includes recalculate and GUI update
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
