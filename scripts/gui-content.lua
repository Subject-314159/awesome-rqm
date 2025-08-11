local content = {}

local analyzer = require('analyzer')
local skeleton = require('gui-skeleton')
local const = require('const')
local util = require('util')
local state = require('state')

local populate_science_filters = function(player_index, anchor)
    local scitbl = skeleton.get_child(anchor, "allowed_science_table")
    if not scitbl then
        game.print('[RQM] ERROR: Did not find allowed science table, please open a bug report on the mod portal')
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
end

local populate_hide_categories = function(player_index, anchor)
    local flow = skeleton.get_child(anchor, "hide_tech_flow")
    flow.clear()
    for k, v in pairs(const.default_settings.player.hide_tech) do
        local state = state.get_player_setting(player_index, k, v)
        local prop = {
            type = "checkbox",
            name = "checkbox_" .. k,
            caption = {"rqm-gui." .. k},
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

local populate_technology = function(player_index, anchor)
    local techtbl = skeleton.get_child(anchor, "available_technology_table")
    if not techtbl then
        return
    end
    techtbl.clear()

    -- for _, t in pairs(player.force.technologies) do
    for _, t in pairs(analyzer.get_filtered_tech_player(player_index)) do

        if analyzer.tech_matches_search_text(player_index, t.name) then
            -- The tech icon
            local icn = techtbl.add({
                type = "sprite-button",
                name = t.name,
                style = "rqm_tech_btn_available",
                sprite = "technology/" .. t.name,
                tags = {
                    rqm_on_click = true,
                    handler = "show_technology_screen"
                }
            })
            if t.researched then
                icn.style = "rqm_tech_btn_researched"
            else
                -- Check if all prerequisites are done
                for _, pt in pairs(t.prerequisites) do
                    if not pt.researched then
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
            n.add({
                type = "label",
                caption = t.localised_name
            })
            local f = n.add({
                type = "flow",
                style = "rqm_horizontal_flow_nospacing",
                direction = "horizontal"
            })
            -- The sciences
            for _, ing in pairs(t.research_unit_ingredients) do
                f.add({
                    type = "sprite",
                    style = "rqm_image_science",
                    sprite = "item/" .. ing.name,
                    tooltip = {"item-name." .. ing.name}
                })
            end
            -- The unlock tech
            local rt = prototypes.technology[t.name].research_trigger
            if rt then
                local pr = {
                    type = "sprite",
                    style = "rqm_image_science"
                }
                if rt.type == "craft-item" and rt.item then
                    pr.sprite = "item/" .. (rt.item.name or rt.item)
                    pr.tooltip = {"item-name." .. (rt.item.name or rt.item)}
                elseif rt.type == "mine-entity" and rt.entity then
                    pr.sprite = "entity/" .. (rt.entity.name or rt.entity)
                    pr.tooltip = {"entity-name." .. (rt.entity.name or rt.entity)}
                elseif rt.type == "craft-fluid" and rt.fluid then
                    pr.sprite = "fluid/" .. (rt.fluid.name or rt.fluid)
                    pr.tooltip = {"fluid-name." .. (rt.fluid.name or rt.fluid)}
                elseif rt.type == "capture-spawner" and rt.entity then
                    pr.sprite = "entity/" .. (rt.entity.name or rt.entity)
                    pr.tooltip = {"entity-name." .. (rt.entity.name or rt.entity)}
                elseif rt.type == "build-entity" and rt.entity then
                    pr.sprite = "entity/" .. (rt.entity.name or rt.entity)
                    pr.tooltip = {"entity-name." .. (rt.entity.name or rt.entity)}
                elseif rt.type == "send-item-to-orbit" and rt.item then
                    pr.sprite = "item/" .. (rt.item.name or rt.item)
                    pr.tooltip = {"item-name." .. (rt.item.name or rt.item)}
                else
                    pr.sprite = "utility/questionmark"
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
                    technology = t.name
                }
            })
            f1.add({
                type = "sprite-button",
                style = "rqm_icon_button",
                sprite = "rqm_arrow_down_small",
                tags = {
                    rqm_on_click = true,
                    handler = "add_queue_bottom",
                    technology = t.name
                }
            })
            -- The bookmark/blacklist buttons
            -- local f2 = fo.add({
            --     type = "flow",
            --     direction = "vertical"
            -- })
            -- f2.add({
            --     type = "sprite-button",
            --     style = "rqm_icon_button",
            --     sprite = "rqm_bookmark_small",
            --     tags = {
            --         rqm_on_click = true,
            --         handler = "add_queue_top",
            --         technology = t.name
            --     }
            -- })
            -- f2.add({
            --     type = "sprite-button",
            --     style = "rqm_icon_button",
            --     sprite = "rqm_blacklist_small",
            --     tags = {
            --         rqm_on_click = true,
            --         handler = "add_queue_bottom",
            --         technology = t.name
            --     }
            -- })
        end
    end
end

local populate_settings = function(player_index, anchor)
    local flow = skeleton.get_child(anchor, "pane_settings")
    if not flow then
        game.print("[RQM] ERROR: Unable to find settings pane, please report a bug on the mod portal")
        return
    end
    flow.clear()

    local data = {{
        settings = const.default_settings.player.settings_tab,
        target = "player"
    }, {
        settings = const.default_settings.force.settings_tab,
        target = "force"
    }}

    for _, p in pairs(data) do
        flow.add({
            type = "label",
            style = "heading_2_label",
            caption = {"rqm-gui.label_" .. p.target .. "_settings"}
        })
        local fn
        if p.target == "player" then
            fn = state.get_player_setting

        else
            fn = state.get_force_setting
        end
        local h = "toggle_checkbox_" .. p.target
        for k, v in pairs(p.settings) do
            local state
            state = fn(player_index, k, v)

            local prop = {
                type = "checkbox",
                name = "checkbox_" .. k,
                caption = {"rqm-gui." .. k},
                state = state,
                tags = {
                    rqm_on_state_change = true,
                    handler = h,
                    setting_name = k
                }
            }
            flow.add(prop)
        end
    end
end

local populate_queue = function(player_index, anchor)
    -- Get the player
    local player = game.get_player(player_index)
    if not player then
        return
    end

    local tblq = skeleton.get_child(anchor, "table_queue")
    if not tblq then
        return
    end
    tblq.clear()

    local gf = storage.forces[player.force.index]
    if not gf or not gf.queue or next(gf.queue) == nil then
        tblq.add({
            type = "label",
            caption = {"rqm-gui.message-empty-queue"}
        })
        return
    end

    local fl

    local i = 1
    for _, q in pairs(gf.queue) do
        -- Prio listbox
        fl = tblq.add({
            type = "flow",
            style = "rqm_horizontal_flow_padded"
        })
        fl.add({
            -- type = "textfield",
            type = "label",
            style = "rqm_queue_index_label",
            caption = i,
            name = q.technology.name .. "_textfield",
            -- style = "rqm_queue_prio_textfield",
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
            }
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
            }
        })

        -- Status
        -- TODO: Get actual status & display correct icon
        -- local spr
        -- if player.force.current_research == q.technology.name then
        --     spr = "rqm_progress_small"
        -- else
        --     spr = "rqm_plus_small"
        -- end
        fl = tblq.add({
            type = "flow",
            style = "rqm_horizontal_flow_padded"
        })
        local spr, tt
        if gf.target_queue_tech_name == q.technology_name then
            spr = "rqm_progress_medium"
        elseif q.metadata.is_inherited then
            spr = "rqm_inherit_medium"

            -- Find the technology that makes this tech inherited
            local inh = ""
            for _, qi in pairs(gf.queue) do
                if qi.technology_name == q.technology_name then
                    break
                end
                if util.array_has_value(qi.metadata.all_predecessors or {}, q.technology_name) then
                    inh = inh ..
                              (state.get_translation(player_index, "technology", qi.technology_name, "localised_name") or
                                  qi.technology_name) .. ", "
                end
            end
            tt = {"rqm-tt.inherited-by", inh}
        elseif q.metadata.is_blocked then
            spr = "rqm_blocked_medium"
            local bt = ''
            for _, b in pairs {q.metadata.blocking_tech} do
                for _, t in pairs(b) do
                    -- local prop = player.force.technologies[b].localised_name
                    bt = bt .. (state.get_translation(player_index, "technology", t, "localised_name") or t) .. ", "
                end
            end
            tt = {"rqm-tt.blocked-tech", bt}
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

        -- Tech name & sciences
        local n = tblq.add({
            type = "flow",
            direction = "vertical",
            style = "rqm_vertical_flow_nospacing"
        })
        n.add({
            type = "label",
            caption = q.technology.localised_name
        })
        -- Additional info on how many (un)blocked predecessors
        local un = (#q.metadata.new_unblocked + #q.metadata.inherit_unblocked)
        local bl = (#q.metadata.new_blocked + #q.metadata.inherit_blocked)
        if (un + bl) > 0 then
            -- local str = "+" .. (un + bl) .. " prerequisite technologies (" ..
            --                 (#q.metadata.new_unblocked + #q.metadata.new_blocked) .. " new & " ..
            --                 (#q.metadata.inherit_unblocked + #q.metadata.inherit_blocked) .. " inherited)"
            local str = "  +" .. (un + bl) .. " prerequisite technologies"
            n.add({
                type = "label",
                style = "rqm_queue_subinfo",
                caption = str
            })
        end
        if bl > 0 then
            -- local str = "  of which " .. bl .. " are blocked (" .. #q.metadata.new_blocked .. " new & " ..
            --                 #q.metadata.inherit_blocked .. " inherited)"
            local str = "    of which " .. #q.metadata.blocking_tech .. " is/are blocking"
            n.add({
                type = "label",
                style = "rqm_queue_subinfo",
                caption = str
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

local set_master_enable = function(player_index, anchor)
    -- Get player and force
    local p = game.get_player(player_index)
    local f = p.force

    -- Get the master switch
    local sw = skeleton.get_child(anchor, "master_enable")

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
        disenable_recursive(skeleton.get_child(anchor, c), enbl)
    end
end

content.repopulate_static = function(player_index, anchor)
    populate_science_filters(player_index, anchor)
    populate_hide_categories(player_index, anchor)
    populate_settings(player_index, anchor)
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
