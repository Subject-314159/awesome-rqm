local tech = require("model.tech")
local env = require("model.env")
local state = require("model.state")
local queue = require("model.queue")
local cmd = require("model.cmd")
local lab = require("model.lab")
local gui = require("view.gui")
local const = require("lib.const")
local util = require("lib.util")

----------------------------------------------------------------------------------------------------
-- INITIALIZATION
----------------------------------------------------------------------------------------------------

local init_player = function(player_index)
    if not storage then
        return
    end
    -- Init storage
    if not player_index then
        return
    end
    if not storage.players[player_index] then
        storage.players[player_index] = {}
    end

    -- Init each module
    state.init_player(player_index)
    gui.init_player(player_index)
end
local init_force = function(force_index)
    if not storage then
        return
    end
    -- Init storage
    if not storage.forces[force_index] then
        storage.forces[force_index] = {}
    end

    -- Init each module
    state.init_force(force_index)
    tech.init_force(force_index)
    queue.init_force(force_index)
    lab.init_force(force_index)
end

local init = function()
    -- Init storage
    if not storage then
        storage = {}
    end
    if not storage.forces then
        storage.forces = {}
    end
    if not storage.players then
        storage.players = {}
    end

    -- Init each module
    env.init()
    lab.init()

    -- Init each force
    for _, f in pairs(game.forces) do
        init_force(f.index)
    end

    -- Init each player
    for _, p in pairs(game.players) do
        init_player(p.index)
    end
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

    -- Sync each force's in-game queue
    for _, f in pairs(game.forces) do
        queue.sync_ingame_queue(f)
    end
end)

script.on_load(function()
    load()
end)

script.on_event({defines.events.on_player_created, defines.events.on_player_joined_game}, function(e)
    init_player(e.player_index)
end)
script.on_event({defines.events.on_force_created}, function(e)
    init_force(e.force.index)
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
    for _, f in pairs(game.forces) do
        local refresh_gui = false

        if state.queue_needs_sync(f) then
            queue.sync_ingame_queue(f)
            refresh_gui = true
        end
        if state.research_needs_next(f) then
            queue.start_next_research(f)
            refresh_gui = true
        end
        if state.ingame_queue_needs_cleanup(f) then
            queue.clean_ingame_queue_timeout(f)
            refresh_gui = true
        end
        if state.gui_needs_update(f) or refresh_gui then
            gui.repopulate_open(f.index)
        end
    end
end)

script.on_nth_tick(42, function(e)
    -- Do the staggered lab update
    lab.tick_update()

    -- Check for each force if the research queue is stuck
    for _, f in pairs(game.forces) do
        -- if queue.is_research_stuck(f) then
        state.request_next_research(f)
        -- end
    end
end)

----------------------------------------------------------------------------------------------------
-- RESEARCH
----------------------------------------------------------------------------------------------------

script.on_event(defines.events.on_research_finished, function(e)
    -- Use the force, luke
    local f = e.research.force
    tech.update_researched(f.index, e.research.name)
    queue.requeue_finished(f, e.research)
    state.request_next_research(f)
end)

script.on_event({defines.events.on_research_queued, defines.events.on_research_moved}, function(e)
    -- When ingame research queue gets modified we need to sync that to our modqueue
    local f = e.force
    state.request_queue_sync(f)
    state.request_ingame_queue_cleanup(f)
end)
script.on_event(defines.events.on_research_cancelled, function(e)
    local f = e.force
    for tn, _ in pairs(e.research) do
        queue.remove(e.force, tn)
    end
    state.request_ingame_queue_cleanup(f)
end)

script.on_event(defines.events.on_research_reversed, function(e)
    -- When a tech gets reversed we need to request a next research
    -- Because the one we are researching right now might no longer be available
    local f = e.research.force

    tech.update_researched(f.index, e.research.name)
    state.request_next_research(f)
end)

----------------------------------------------------------------------------------------------------
-- ENTITY
----------------------------------------------------------------------------------------------------
local labfilter = {{
    filter = "type",
    type = "lab"
}}
script.on_event(defines.events.on_built_entity, function(e)
    lab.register(e.entity)
end, labfilter)
script.on_event(defines.events.on_robot_built_entity, function(e)
    lab.register(e.entity)
end, labfilter)
script.on_event(defines.events.script_raised_built, function(e)
    lab.register(e.entity)
end, labfilter)

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
    elseif h == "produced_science" then
        local sci = util.get_all_sciences()
        for _, s in pairs(sci) do
            state.set_player_setting(p.index, "allowed_" .. s, false)
        end
        local prod = lab.get_labs_fill_rate(f.index)
        for s, _ in pairs(prod) do
            state.set_player_setting(p.index, "allowed_" .. s, true)
        end
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
    elseif h == "search" then
        if gui.is_search_focussed(p.index) then
            gui.defocus_search(p.index)
        else
            gui.focus_search(p.index)
        end
    elseif h == "master_enable" then
        local st = state.get_force_setting(f.index, "master_enable", const.default_settings.force.master_enable)
        if st == "left" then
            st = "right"
        else
            st = "left"
        end
        state.set_force_setting(f.index, "master_enable", st)
        state.request_next_research(f)
    end

    -- Refresh all open GUIs to reflect the changes
    if repopulate then
        gui.repopulate_open(f.index)
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
        state.set_force_setting(f.index, t.setting_name, e.element.state)
        if t.setting_name == "auto_research" then
            state.request_next_research(f)
        end
    end

    -- Refresh all open GUIs to reflect the changes
    if repopulate then
        gui.repopulate_open(f.index)
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
        state.request_next_research(f)
    end

    -- Refresh all open GUIs to reflect the changes
    if repopulate then
        gui.repopulate_open(f.index)
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
