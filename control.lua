-- Classes
local gui = require('scripts/gui')
local scheduler = require('scripts/scheduler')
local const = require('scripts/const')
local state = require('scripts/state')
local util = require('scripts/util')

local flags = {}

local set_tick_flag = function(force, tick)
    if not flags[force.index] then
        flags[force.index] = {}
    end
    flags[force.index].tick = tick
end

local get_tick_flag = function(force)
    if not flags[force.index] then
        return
    end
    return flags[force.index].tick
end

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
        -- Store the current progress
        if not storage.forces then
            storage.forces = {}
        end
        if not storage.forces[f.index] then
            storage.forces[f.index] = {}
        end
        if not storage.forces[f.index].progress then
            storage.forces[f.index].progress = {}
        end
        local sfp = storage.forces[f.index].progress
        sfp[e.tick] = f.research_progress

        -- Only if we have one tech in the queue left
        if #f.research_queue == 1 then
            -- Calculate the average progress per tick
            local i, minp, maxp = 0, 0, 0
            for tick, progress in pairs(sfp) do
                if tick < e.tick - 30 then
                    sfp[tick] = nil
                else
                    if progress < minp or minp == 0 then
                        minp = progress
                    end
                    if progress > maxp then
                        maxp = progress
                    end
                    i = i + 1
                end
            end
            local spd = (maxp - minp) / i
            -- game.print("spd: " .. spd)

            -- Check if in next ticks we would finish the research
            if f.research_progress + (3 * spd) >= 1 then
                -- game.print("Predict")
                -- Enable and add our dummy research
                f.technologies["rqm-dummy-technology"].enabled = true
                local que = {f.research_queue[1], f.technologies["rqm-dummy-technology"]}
                -- game.print(serpent.line(que))
                f.research_queue = que
                -- f.research_queue[2] = f.technologies["rqm-dummy-technology"]
                -- table.insert(f.research_queue, f.technologies["rqm-dummy-technology"])
            end
        end

        -- if f.technologies["rqm-dummy-technology"].enabled then
        --     f.technologies["rqm-dummy-technology"].enabled = false
        -- end

        -- Cleanup queue after time-out
        local gf = storage.forces[f.index]
        if gf["last_queue_match_tick"] and game.tick >= gf["last_queue_match_tick"] +
            const.default_settings.force.research_queue_cleanup_timeout then

            set_tick_flag(f, game.tick)
            local que = {f.research_queue[1]}
            f.research_queue = que
            -- scheduler.start_next_research(f)
            gui.repopulate_open()
            gf["last_queue_match_tick"] = nil
            f.print({"rqm-msg.auto-cleanup-queue"})
        end
    end
end)

-- keybinding hooks
script.on_event("rqm_toggle_gui", function(event)
    gui.toggle(event.player_index)
end)

script.on_event("rqm_focus_search", function(event)
    gui.focus_search(event.player_index)
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
        set_tick_flag(f, game.tick)
        scheduler.queue_research(f, t.technology, 1)
    elseif h == "add_queue_bottom" then
        set_tick_flag(f, game.tick)
        scheduler.queue_research(f, t.technology)
    elseif h == "remove_from_queue" then
        set_tick_flag(f, game.tick)
        scheduler.remove_from_queue(f, t.technology)
    elseif h == "toggle_allowed_science" then
        state.toggle_player_setting(p.index, "allowed_" .. t.science)
    elseif h == "promote_research" then
        set_tick_flag(f, game.tick)
        scheduler.promote_research(f, t.tech_name)
    elseif h == "demote_research" then
        set_tick_flag(f, game.tick)
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

    gui.repopulate_open()
end)

-- Update our queue after the user interacted with the in-game queue
script.on_event({defines.events.on_research_cancelled, defines.events.on_research_queued,
                 defines.events.on_research_moved}, function(e)
    -- Get the affected tech
    local tech
    if e.name == "on_research_cancelled" then
        for k, v in pairs(e.research) do
            tech = k
        end
    elseif e.name == "on_research_queued" then
        tech = e.research.name
    end

    -- Check if we have the tick flag
    if get_tick_flag(e.force) == game.tick then
        game.print("Skipping because same tick")
        return
    else
        game.print(serpent.line(get_tick_flag(e.force)) .. " is not equal to game tick " .. game.tick)
    end
    scheduler.match_queue(e.force, tech)
    gui.repopulate_open()
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
