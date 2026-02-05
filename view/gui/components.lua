local const = require("lib.const")
local util = require("lib.util")
local state = require("model.state")
local tech = require("model.tech")
local analyzer = require("view.gui.analyzer")

local gutil = require("view.gui.gutil")
local gcqueue = require("view.gui.components.queue")
local gctech = require("view.gui.components.tech")

local content = {}

local populate_force_settings = function(player_index, anchor)
    -- Dropdown
    -- local name = "announcement_level"
    -- local dl
    -- for i, v in ipairs(const.announcements) do
    --     if v == const.default_settings.force.announcement_level then
    --         dl = i
    --     end
    -- end
    -- local elm = gutil.get_child(anchor, name)
    -- local lvl = state.get_force_setting(player_index, name, dl)
    -- elm.selected_index = lvl

    -- Checkboxes
    local flow = gutil.get_child(anchor, "force_settings_flow")
    if not flow then
        -- For some reason when an equipment grid is opened and we try to open the queue
        -- The game crashes because we can't find the flow
        -- As containment we just exit here
        return
    end
    flow.clear()
    for k, v in pairs(const.default_settings.force.settings) do
        local state = state.get_force_setting(player_index, k, v)
        local prop = {
            type = "checkbox",
            name = k,
            caption = {"rqm-force-settings." .. k},
            state = state,
            -- state = false,
            tags = {
                rqm_on_state_change = true,
                handler = "toggle_checkbox_force",
                setting_name = k
            }
        }
        flow.add(prop)
    end

    for k, v in pairs(const.default_settings.force.global_settings) do
        local tt = {"", "[font=default-bold]This is a mod setting, go to settings > mod settings to change it[/font]\n",
                    "", {"mod-setting-description." .. v}, ""}
        local state = settings.global[v].value
        local ifl = flow.add({
            type = "flow",
            direction = "horizontal",
            tooltip = tt
        })
        ifl.add({
            type = "checkbox",
            name = v,
            caption = {"", {"mod-setting-name." .. v}},
            state = state,
            enabled = false,
            tooltip = tt
        })
        ifl.add({
            type = "sprite",
            sprite = "info",
            tooltip = tt
        })
    end
end

local populate_science_filters = function(player_index, anchor)
    local scitbl = gutil.get_child(anchor, "allowed_science_table")
    if not scitbl then
        game.print("[RQM] ERROR: Did not find allowed science table, please open a bug report on the mod portal")
        return
    end
    scitbl.clear()

    local sci = util.get_all_sciences()

    -- Add all the sciences as icons to the table
    for _, s in pairs(sci) do
        -- TODO: Read player settings and set button enabled/disabled
        local sprop = {
            type = "sprite-button",
            sprite = "item/" .. s,
            toggled = state.get_player_setting(player_index, "allowed_" .. s, false),
            tooltip = {"item-name." .. s},
            tags = {
                rqm_on_click = true,
                handler = "toggle_allowed_science",
                science = s
            }
        }
        scitbl.add(sprop)
    end

    -- Dynamically adjust height based on number of sciences
    local sp = gutil.get_child(anchor, "sci_scroll")
    sp.style.height = 48
    if #sci > 14 and #sci <= 28 then
        sp.style.height = 92
    elseif #sci > 28 then
        sp.style.height = 136
    end
end

local populate_hide_categories = function(player_index, anchor)
    local flow = gutil.get_child(anchor, "hide_tech_flow")
    flow.clear()
    for k, v in pairs(const.default_settings.player.hide_tech) do
        local state = state.get_player_setting(player_index, k, v)
        local prop = {
            type = "checkbox",
            name = k,
            caption = {"rqm-hide-tech." .. k},
            state = state,
            tags = {
                rqm_on_state_change = true,
                handler = "toggle_checkbox_player",
                setting_name = k
            }
        }
        flow.add(prop)
    end
end

local populate_show_categories = function(player_index, anchor)
    local flow = gutil.get_child(anchor, "show_tech_flow")
    flow.clear()
    local setting = "show_tech_filter_category"
    local selected = state.get_player_setting(player_index, setting, const.default_settings.player.show_tech.selected)
    for k, v in pairs(const.categories) do
        local prop = {
            type = "radiobutton",
            name = k,
            caption = {"rqm-filter-category." .. k},
            state = k == selected,
            tags = {
                rqm_on_state_change = true,
                handler = "toggle_radiobutton_player",
                setting_name = setting
            }
        }
        flow.add(prop)
    end
end

local set_master_enable = function(player_index, anchor)
    -- Get player and force
    local p = game.get_player(player_index)
    local f = p.force

    -- Get the master switch
    local sw = gutil.get_child(anchor, "master_enable")

    -- Get the state from storage or default settings
    local st = state.get_force_setting(f.index, "master_enable")
    if st == nil then
        st = const.default_settings.force.master_enable
    end

    -- Set the state
    sw.switch_state = st

    -- Disable/enable the rest of the content based on the state
    -- Forward delcare recursive function

    -- The new enabled state for the elements
    local enbl = true
    local lbl = gutil.get_child(anchor, "master_enable_label")
    lbl.style = "bold_label"
    lbl.style.font_color = {0.945, 0.745, 0.392}
    if st == "left" then
        enbl = false
        lbl.style = "label"
    end

    -- Loop through entry point elements
    for _, c in pairs({"queue_pane", "right"}) do
        -- Get the child element, then call recursive function for that element
        gutil.disenable_recursive(gutil.get_child(anchor, c), enbl)
    end
end

local update_styles = function(player_index, anchor)
    local lbl
    lbl = gutil.get_child(anchor, "available_tech_lbl")
    lbl.style.bottom_margin = 4

    lbl = gutil.get_child(anchor, "master_enable_flow")
    lbl.style.top_margin = 24
    -- lbl.style.bottom_margin = 10
end

content.repopulate_static = function(player_index, anchor)
    populate_force_settings(player_index, anchor)
    populate_science_filters(player_index, anchor)
    populate_hide_categories(player_index, anchor)
    populate_show_categories(player_index, anchor)
    update_styles(player_index, anchor)
end

content.repopulate_dynamic = function(player_index, anchor)
    gctech.populate(player_index, anchor)
    gcqueue.populate(player_index, anchor)
    set_master_enable(player_index, anchor)
end

content.repopulate_all = function(player_index, anchor)
    content.repopulate_static(player_index, anchor)
    content.repopulate_dynamic(player_index, anchor)
end

content.repopulate_tech = function(player_index, anchor)
    gctech.populate(player_index, anchor)
end

return content
