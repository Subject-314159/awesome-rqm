-- Classes
local gui = require('scripts/gui')
local scheduler = require('scripts/scheduler')
local observer = require('scripts/observer')
local const = require('scripts/const')
local state = require('scripts/state')
local util = require('scripts/util')

local init = function()
    state.init()
    scheduler.init()
    gui.close_all_open()
end

local load = function()
    -- scheduler.load()
    -- Register custom commands
    commands.add_command("rqm_debug", "Generates debug info in the game log", function(command)
        -- Get the force
        local frc = game.get_player(command.player_index).force

        scheduler.clear_queue(frc)

        -- Set the initial techs as unlocked
        frc.reset()
        local techs = {"electronics", "steam-power", "automation"}
        for _, t in pairs(techs) do
            frc.technologies[t].research_recursive()
        end

        -- Add technology
        scheduler.queue_research(frc, "automobilism")
        scheduler.queue_research(frc, "oil-gathering")
        scheduler.queue_research(frc, "fluid-handling")

        -- Repopulate open GUIs
        gui.repopulate_open()

        -- Redo the translations
        state.init()
    end)
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
    init()
end)

script.on_event(defines.events.on_tick, function(e)
    for _, f in pairs(game.forces) do
        local gf = util.get_global_force(f)

        -- Store the current progress
        -- Only if we have one tech in the queue left
        -- And (we have more than one tech in our own que, or the current research is not the first item in our queue)
        if #f.research_queue == 1 then
            if #gf.queue > 1 or gf.queue[1].technology_name ~= f.research_queue[1].name then
                -- Buffer the progress
                observer.buffer_current_progress(f, f.current_research.name, game.tick, f.research_progress)

                -- Get the research speed
                local spd = observer.get_average_progress_speed(f, f.current_research.name)

                -- Check if in next ticks we would finish the research
                if f.research_progress + (3 * spd) >= 1 then
                    -- Enable and add our dummy research
                    f.technologies["rqm-dummy-technology"].enabled = true
                    local que = {f.research_queue[1], f.technologies["rqm-dummy-technology"]}
                    f.research_queue = que
                end
            end
        end

        -- Cleanup queue after time-out
        -- Remember only the first tech in the in-game queue, then overwrite the in-game queue with only this tech, removing all others
        -- Then repopulate open GUIs, clear the flag and notify user
        if gf["last_queue_match_tick"] then
            local threshold = gf["last_queue_match_tick"] + const.default_settings.force.research_queue_cleanup_timeout
            if game.tick >= threshold then
                game.print("Cleanup")
                local que = {f.research_queue[1]}
                f.research_queue = que
                -- scheduler.start_next_research(f)
                gui.repopulate_open()
                gf["last_queue_match_tick"] = nil
                f.print({"rqm-msg.auto-cleanup-queue"})
            end
        end
    end

end)

-- keybinding hooks
script.on_event("rqm_toggle_gui", function(e)
    gui.toggle(e.player_index)
end)
script.on_event(defines.events.on_lua_shortcut, function(e)
    if e.prototype_name == "rqm_shortcut" then
        gui.toggle(e.player_index)
    end
end)

script.on_event("rqm_focus_search", function(e)
    gui.focus_search(e.player_index)
end)

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
        scheduler.queue_research(f, t.technology, 1)
    elseif h == "add_queue_bottom" then
        scheduler.queue_research(f, t.technology)
    elseif h == "remove_from_queue" then
        scheduler.remove_from_queue(f, t.technology)
    elseif h == "toggle_allowed_science" then
        state.toggle_player_setting(p.index, "allowed_" .. t.science)
    elseif h == "promote_research" then
        scheduler.promote_research(f, t.tech_name)
    elseif h == "demote_research" then
        scheduler.demote_research(f, t.tech_name)
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
    if h == "toggle_checkbox" then
        state.set_player_setting(e.player_index, t.setting_name, e.element.state)
    end

    -- Refresh all open GUIs to reflect the changes
    if repopulate then
        gui.repopulate_open()
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
        scheduler.recalculate_queue(f)
        scheduler.start_next_research(f)
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
    state.store_translation(e.player_index, e.id, e.result, e.localised_string)
end)

script.on_event(defines.events.on_research_finished, function(e)

    local f = e.research.force

    -- Disable our dummy tech
    f.technologies["rqm-dummy-technology"].enabled = false

    -- Remove it from the in-game queue
    local que = {}
    for k, v in pairs(f.research_queue) do
        if v.name ~= "rqm-dummy-technology" then
            que[k] = v
        end
    end
    f.research_queue = que

    -- Start next research (no need to check if RQM is enabled, is done in start_next_research)
    -- local st = state.get_force_setting(f.index, "master_enable")
    -- if st == "right" then
    scheduler.recalculate_queue(f)
    scheduler.start_next_research(f)
    -- end

    -- Clean up data for average speed calculation
    observer.delete_tech_progress(f, e.research.name)

    gui.repopulate_open()
end)
local on_research = function(e)
    -- Get the affected tech
    local tech
    if e.name == 23 then -- on_research_cancelled
        for k, v in pairs(e.research) do
            tech = k
        end
        scheduler.remove_from_queue(e.force, tech)
    elseif e.name == 24 then -- on_research_queued
        tech = e.research.name
    end

    scheduler.sync_queue(e.force, tech)
    gui.repopulate_open()
end
-- Update our queue after the user interacted with the in-game queue
script.on_event({defines.events.on_research_cancelled}, function(e)
    on_research(e)
end)
script.on_event({defines.events.on_research_queued}, function(e)
    on_research(e)
end)
script.on_event({defines.events.on_research_moved}, function(e)
    on_research(e)
end)
script.on_event({defines.events.on_research_reversed}, function(e)
    -- When research is reversed this will influence our queue, so we neeed to recalculate and restart it
    -- Then repopulate all open GUIs to reflect changes

    -- Use the force, luke
    local f = e.research.force
    -- scheduler.match_queue(f)
    scheduler.recalculate_queue(f)
    scheduler.start_next_research(f)
    gui.repopulate_open()
end)
