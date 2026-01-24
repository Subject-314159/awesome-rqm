local content = {}

local analyzer = require("lib.analyzer")
local const = require("lib.const")
local util = require("lib.util")
local gutil = require("scripts.gui.gutil")
local state = require("lib.state")

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

local populate_technology = function(player_index, anchor)
    local player = game.get_player(player_index)
    local force = player.force
    local techtbl = gutil.get_child(anchor, "available_technology_table")
    if not techtbl then
        return
    end
    techtbl.clear()

    local tech_names = state.get_filtered_technologies_player(player_index)
    for _, tn in pairs(tech_names) do
        local t = state.get_technology(force.index, tn)

        -- The tech icon
        local icn = techtbl.add({
            type = "sprite-button",
            name = tn,
            style = "rqm_tech_btn_available",
            sprite = "technology/" .. tn,
            tags = {
                rqm_on_click = true,
                handler = "show_technology_screen"
            }
        })
        if t.technology.researched then
            icn.style = "rqm_tech_btn_researched"
        else
            -- Check if all prerequisites are done
            for pre, _ in pairs(t.prerequisites) do
                local pt = state.get_technology(force.index, pre)
                if not pt.technology.researched then
                    -- We found at least one undone prerequisite
                    icn.style = "rqm_tech_btn_unavailable"
                    break
                end
            end
        end

        -- The flow for the title and sciences
        local s = techtbl.add({
            type = "scroll-pane",
            style = "rqm_horizontal_tech_name_pane",
            direction = "horizontal"
        })

        local n = s.add({
            type = "flow",
            direction = "vertical",
            style = "rqm_vertical_flow"
        })
        -- The name
        local name = gutil.get_tech_name(player_index, t.technology)
        n.add({
            type = "label",
            -- caption = t.localised_name
            caption = name
        })
        local f = n.add({
            type = "flow",
            style = "rqm_horizontal_flow_nospacing",
            direction = "horizontal"
        })
        -- The sciences
        local first = true
        for _, sci in pairs(t.sciences or {}) do
            local ss = f.add({
                type = "sprite",
                sprite = "item/" .. sci,
                tooltip = {"item-name." .. sci}
            })
            -- If there are more than 8 sciences we need to add negative left margin to compensate for each science icon
            -- if not first and #t.research_unit_ingredients > 8 then
            if not first and #t.sciences > 8 then
                ss.style.left_margin = (28 * (#t.sciences - 8)) / -#t.sciences
            end
            first = false
        end
        -- The unlock tech
        if t.has_trigger then
            local rt = t.research_trigger
            local pr = {
                type = "sprite",
                style = "rqm_image_science"
            }
            if rt.type == "craft-item" and rt.item then
                local rtname = (rt.item.name or rt.item)
                local lname = prototypes.item[rtname].localised_name
                local itm = {"", "[item=" .. rtname .. "]", {"gui-text-tags.following-text-item", lname}}
                local cnt = rt.count or 1
                if cnt == 1 then
                    pr.tooltip = {"technology-trigger.craft-item", itm}
                else
                    pr.tooltip = {"technology-trigger.craft-items", cnt, itm}
                end
                pr.sprite = "item/" .. rtname
            elseif rt.type == "mine-entity" and rt.entity then
                local rtname = (rt.entity.name or rt.entity)
                local lname = prototypes.entity[rtname].localised_name
                local itm = {"", "[entity=" .. rtname .. "]", {"gui-text-tags.following-text-entity", lname}}
                pr.tooltip = {"technology-trigger.mine-entity", itm}
                pr.sprite = "entity/" .. rtname
            elseif rt.type == "craft-fluid" and rt.fluid then
                local rtname = (rt.fluid.name or rt.fluid)
                local lname = prototypes.fluid[rtname].localised_name
                local itm = {"", "[entity=" .. rtname .. "]", {"gui-text-tags.following-text-fluid", lname}}
                pr.tooltip = {"technology-trigger.craft-fluid", itm}
                pr.sprite = "fluid/" .. rtname
            elseif rt.type == "capture-spawner" then
                if rt.entity then
                    local rtname = (rt.entity.name or rt.entity)
                    local lname = prototypes.entity[rtname].localised_name
                    local itm = {"", "[entity=" .. rtname .. "]", {"gui-text-tags.following-text-entity", lname}}
                    pr.tooltip = {"technology-trigger.capture-spawner", itm}
                    pr.sprite = "entity/" .. rtname
                else
                    -- TODO: Add custom trigger unlock image
                    pr.type = "label"
                    pr.style = nil
                    pr.caption = {"technology-trigger.capture-any-spawner"}
                end
            elseif rt.type == "build-entity" and rt.entity then
                local rtname = (rt.entity.name or rt.entity)
                local lname = prototypes.entity[rtname].localised_name
                local itm = {"", "[entity=" .. rtname .. "]", {"gui-text-tags.following-text-entity", lname}}
                pr.tooltip = {"technology-trigger.build-entity", itm}
                pr.sprite = "entity/" .. rtname
            elseif rt.type == "create-space-platform" then
                local rtname = ("space-platform-starter-pack")
                local lname = prototypes.item[rtname].localised_name
                local itm = {"", "[item=" .. rtname .. "]", {"gui-text-tags.following-text-item", lname}}
                pr.tooltip = {"technology-trigger.create-space-platform-specific", itm}
                pr.sprite = "item/space-platform-starter-pack"
            elseif rt.type == "send-item-to-orbit" and rt.item then
                local rtname = (rt.item.name or rt.item)
                local lname = prototypes.item[rtname].localised_name
                local itm = {"", "[item=" .. rtname .. "]", {"gui-text-tags.following-text-item", lname}}
                pr.tooltip = {"technology-trigger.send-item-to-orbit", itm}
                pr.sprite = "item/" .. rtname
            elseif rt.type == "scripted" then
                pr.tooltip = rt.trigger_description
                pr.sprite = "utility/questionmark"
            else
                pr.tooltip = tn .. " has unknown research trigger, please open a bug report in the mod portal"
                pr.sprite = "utility/danger_icon"
            end
            f.add(pr)

            icn.style = "rqm_tech_btn_blocked"
        end

        -- Flow for the control buttons
        local fo = techtbl.add({
            type = "flow",
            direction = "horizontal",
            style = "rqm_horizontal_flow_padded"
        })
        -- The add to queue buttons
        local f1 = fo.add({
            type = "flow",
            direction = "vertical"
        })
        f1.add({
            type = "sprite-button",
            style = "rqm_icon_button",
            sprite = "rqm_arrow_up_small",
            tags = {
                rqm_on_click = true,
                handler = "add_queue_top",
                technology = tn
            }
        })
        f1.add({
            type = "sprite-button",
            style = "rqm_icon_button",
            sprite = "rqm_arrow_down_small",
            tags = {
                rqm_on_click = true,
                handler = "add_queue_bottom",
                technology = tn
            }
        })
    end
end

local populate_queue = function(player_index, anchor)
    -- Get the player
    local player = game.get_player(player_index)
    if not player then
        return
    end
    local f = player.force

    local tblq = gutil.get_child(anchor, "table_queue")
    if not tblq then
        return
    end
    tblq.clear()

    local gf = storage.forces[player.force.index]
    if not gf or not gf.queue or next(gf.queue) == nil then
        tblq.add({
            type = "label",
            caption = {"rqm-lbl.empty-queue"}
        })
        return
    end

    local fl

    local i = 1
    for _, q in pairs(gf.queue) do
        if q ~= nil and q.technology.valid then
            -- Prio listbox
            fl = tblq.add({
                type = "flow",
                style = "rqm_horizontal_flow_padded"
            })
            fl.add({
                type = "label",
                style = "rqm_queue_index_label",
                caption = i,
                name = q.technology.name .. "_textfield",
                lose_focus_on_confirm = true
            })

            -- Buttons
            fl = tblq.add({
                type = "flow",
                direction = "vertical"
            })
            local enbl, ign
            if i == 1 then
                enbl = false
                ign = true
            else
                enbl = nil
                ign = nil
            end
            fl.add({
                type = "sprite-button",
                style = "rqm_icon_button",
                sprite = "rqm_arrow_up_small",
                enabled = enbl,
                tags = {
                    rqm_on_click = true,
                    handler = "promote_research",
                    tech_name = q.technology.name,
                    ignore_force_enable = ign
                },
                tooltip = {"rqm-gui.promote_tooltip"}
            })
            if i == #gf.queue then
                enbl = false
                ign = true
            else
                enbl = nil
                ign = nil
            end
            fl.add({
                type = "sprite-button",
                style = "rqm_icon_button",
                sprite = "rqm_arrow_down_small",
                enabled = enbl,
                tags = {
                    rqm_on_click = true,
                    handler = "demote_research",
                    tech_name = q.technology.name,
                    ignore_force_enable = ign
                },
                tooltip = {"rqm-gui.demote_tooltip"}
            })

            -- Status symbol
            -- TODO: Get actual status & display correct icon
            fl = tblq.add({
                type = "flow",
                style = "rqm_horizontal_flow_queue_status"
            })
            local spr, tt
            if gf.target_queue_tech_name == q.technology_name then
                spr = "rqm_progress_medium"
            elseif q.metadata.is_inherited then
                spr = "rqm_inherit_medium"

                -- Find the technology that makes this tech inherited
                local inh = ""
                for k, qi in pairs(gf.queue) do
                    if qi.technology_name == q.technology_name then
                        break
                    end
                    if util.array_has_value(qi.metadata.all_predecessors or {}, q.technology_name) then
                        inh = inh ..
                                  (state.get_translation(player_index, "technology", qi.technology_name,
                                "localised_name") or qi.technology_name) .. ", "
                    end
                    -- Remove the trailing comma
                    if #inh > 2 then
                        inh = string.sub(inh, 1, -3)
                    end
                end
                tt = {"rqm-tt.inherited-by", inh}
            elseif q.metadata.is_blocked then
                spr = "rqm_blocked_medium"
                local bt = {""}
                for r, b in pairs(q.metadata.blocking_reasons or {}) do
                    local ttr = ""
                    for k, t in pairs(b) do
                        ttr = ttr .. (state.get_translation(player_index, "technology", t, "localised_name") or t)
                        if next(b, k) ~= nil then
                            ttr = ttr .. ", "
                        end
                    end
                    if next(q.metadata.blocking_reasons, r) ~= nil then
                        ttr = ttr .. "\n"
                    end
                    table.insert(bt, {"rqm-tt.blocked_" .. r, ttr})
                end
                tt = {"rqm-tt.blocked", bt}
            else
                spr = "rqm_queue_medium"
            end
            fl.add({
                type = "sprite",
                sprite = spr,
                tooltip = tt
            })

            -- TODO: Move this to separate function & re-use the logic from available tech
            -- Tech icon
            tblq.add({
                type = "sprite-button",
                name = q.technology.name,
                style = "rqm_tech_btn_available",
                sprite = "technology/" .. q.technology.name,
                tags = {
                    rqm_on_click = true,
                    handler = "show_technology_screen"
                }
            })

            -- Tech name, info & sciences (possibly)
            local name = gutil.get_tech_name(player_index, q.technology)
            local n = tblq.add({
                type = "flow",
                direction = "vertical",
                style = "rqm_vertical_flow_nospacing"
            })
            n.add({
                type = "label",
                caption = name
            })

            -- Additional info on how many (un)blocked predecessors
            local un = (#q.metadata.new_unblocked + #q.metadata.inherit_unblocked)
            local bl = (#q.metadata.new_blocked + #q.metadata.inherit_blocked)
            if un > 0 then
                local ttp = ""
                for _, u in pairs({q.metadata.new_unblocked, q.metadata.inherit_unblocked}) do
                    for k, t in pairs(u) do
                        ttp = ttp .. (state.get_translation(player_index, "technology", t, "localised_name") or t)
                        if next(u, k) ~= nil then
                            ttp = ttp .. ", "
                        end
                    end
                end

                local ifl = n.add({
                    type = "flow",
                    direction = "horizontal"
                })
                local tt = {"rqm-tt.inherited-tech", ttp}
                ifl.add({
                    type = "label",
                    style = "rqm_queue_subinfo",
                    caption = {"rqm-lbl.prerequisite-tech", (un)},
                    tooltip = tt
                })
                ifl.add({
                    type = "sprite",
                    sprite = "info"
                })
            end
            if bl > 0 then
                local ttp = ""
                for _, u in pairs({q.metadata.new_blocked, q.metadata.inherit_blocked}) do
                    for k, t in pairs(u) do
                        ttp = ttp .. (state.get_translation(player_index, "technology", t, "localised_name") or t)
                        if next(u, k) ~= nil then
                            ttp = ttp .. ", "
                        end
                    end
                end

                local ifl = n.add({
                    type = "flow",
                    direction = "horizontal"
                })
                local lbl = {"rqm-lbl.blocked-tech-only", bl}
                ifl.add({
                    type = "label",
                    style = "rqm_queue_subinfo",
                    caption = lbl,
                    tooltip = {"rqm-tt.blocked-tech", ttp}
                })
                ifl.add({
                    type = "sprite",
                    sprite = "info"
                })
            end

            -- Trash bin
            fl = tblq.add({
                type = "flow",
                style = "rqm_horizontal_flow_padded"
            })
            fl.add({
                type = "sprite-button",
                style = "rqm_icon_button",
                sprite = "rqm_bin_small",
                tags = {
                    rqm_on_click = true,
                    handler = "remove_from_queue",
                    technology = q.technology.name
                }
            })
            i = i + 1
        end
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
    local disenable_recursive
    disenable_recursive = function(elm, enbl)
        if not elm then
            return
        end
        -- Ignore this element if it has the ignore_force_enable tag, i.e.;
        -- Process this element if it does not have tags,
        -- or if it does have tags but not ignore_force_enable
        if not elm.tags or not elm.tags.ignore_force_enable then
            elm.enabled = enbl
        end
        for _, c in pairs(elm.children or {}) do
            disenable_recursive(c, enbl)
        end
    end

    -- The new enabled state for the elements
    local enbl = true
    if st == "left" then
        enbl = false
    end

    -- Loop through entry point elements
    for _, c in pairs({"queue_pane", "right"}) do
        -- Get the child element, then call recursive function for that element
        disenable_recursive(gutil.get_child(anchor, c), enbl)
    end
end

content.repopulate_static = function(player_index, anchor)
    populate_force_settings(player_index, anchor)
    populate_science_filters(player_index, anchor)
    populate_hide_categories(player_index, anchor)
    populate_show_categories(player_index, anchor)
end

content.repopulate_dynamic = function(player_index, anchor)
    populate_technology(player_index, anchor)
    populate_queue(player_index, anchor)
    set_master_enable(player_index, anchor)
end

content.repopulate_all = function(player_index, anchor)
    content.repopulate_static(player_index, anchor)
    content.repopulate_dynamic(player_index, anchor)
end

content.repopulate_tech = function(player_index, anchor)
    populate_technology(player_index, anchor)
end

return content
