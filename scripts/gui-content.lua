local content = {}

local analyzer = require('analyzer')
local skeleton = require('gui-skeleton')
local const = require('const')
local util = require('util')
local state = require('state')

local populate_science_filters = function(player_index, anchor)
    local scitbl = skeleton.get_child(anchor, "allowed_science_table")
    if not scitbl then
        game.print('ERR: Did not find allowed sicence table')
        return
    end
    scitbl.clear()

    -- Get all the labs
    local prop = {
        filter = "type",
        type = "lab"
    }
    local labs = prototypes.get_entity_filtered({prop})

    -- Get all the siences accepted by labs
    local sci = {}
    for _, l in pairs(labs) do
        for _, i in pairs(l.lab_inputs) do
            if not util.array_has_value(sci, i) then
                table.insert(sci, i)
            end
        end
    end

    -- Add all the sciences as icons to the table
    for _, s in pairs(sci) do
        -- TODO: Read player settings and set button enabled/disabled
        local sprop = {
            type = "sprite-button",
            sprite = "item/" .. s,
            toggled = state.get_player_setting(player_index, "allowed_" .. s) or false,
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
        local state = state.get_player_setting(player_index, k)
        if state == nil then
            state = v
        end
        local prop = {
            type = "checkbox",
            name = "checkbox_" .. k,
            caption = {"rqm-gui." .. k},
            state = state,
            tags = {
                rqm_on_state_change = true,
                handler = "toggle_checkbox",
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
    for _, t in pairs(analyzer.get_filtered_tech(player_index)) do

        -- Do generic checks
        local passes_checks = analyzer.tech_matches_search_text(player_index, t.name)

        -- -- Check: Matches any search queue
        -- -- Get the input search text
        -- local src = skeleton.get_child(anchor, "search_textfield")
        -- local txt = src.text

        -- -- Check if it matches localised name of the tech
        -- local gpt = storage.state.players[player.index].translations
        -- local haystack = {}
        -- if txt ~= "" and not util.fuzzy_search(txt, gpt["technology"][t.name]["localised_name"]) then
        --     passes_checks = false
        -- end

        -- -- Check: Tech must be enabled
        -- if not t.enabled then
        --     passes_checks = false
        -- end

        if passes_checks then
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
            local n = techtbl.add({
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
                direction = "horizontal"
            })
            -- The sciences
            for _, ing in pairs(t.research_unit_ingredients) do
                f.add({
                    type = "sprite",
                    style = "rqm_image_science",
                    sprite = "item/" .. ing.name
                })
            end
            -- The unlock tech
            local rt = prototypes.technology[t.name].research_trigger
            if rt then
                -- game.print(serpent.block(rt))
                local pr = {
                    type = "sprite",
                    style = "rqm_image_science"
                }
                if rt.type == "craft-item" and rt.item then
                    pr.sprite = "item/" .. (rt.item.name or rt.item)
                elseif rt.type == "mine-entity" and rt.entity then
                    pr.sprite = "entity/" .. (rt.entity.name or rt.entity)
                elseif rt.type == "craft-fluid" and rt.fluid then
                    pr.sprite = "fluid/" .. (rt.fluid.name or rt.fluid)
                elseif rt.type == "capture-spawner" and rt.entity then
                    pr.sprite = "entity/" .. (rt.entity.name or rt.entity)
                elseif rt.type == "build-entity" and rt.entity then
                    pr.sprite = "entity/" .. (rt.entity.name or rt.entity)
                elseif rt.type == "send-item-to-orbit" and rt.item then
                    pr.sprite = "item/" .. (rt.item.name or rt.item)
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

local populate_queue = function(player_index, anchor)
    -- Get the player
    local player = game.get_player(player_index)
    if not player then
        return
    end

    local tblq = skeleton.get_child(anchor, "table_queue")
    if not tblq then
        game.print("ERR: No queue table found")
        return
    end
    tblq.clear()

    local gf = storage.forces[player.force.index]
    if not gf or not gf.queue or next(gf.queue) == nil then
        tblq.add({
            type = "label",
            caption = "Queue new research to start AwesomeRQM"
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
        fl.add({
            type = "sprite-button",
            style = "rqm_icon_button",
            sprite = "rqm_arrow_up_small"
        })
        fl.add({
            type = "sprite-button",
            style = "rqm_icon_button",
            sprite = "rqm_arrow_down_small"
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
        fl.add({
            type = "sprite",
            sprite = "rqm_queue_medium"
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
            style = "rqm_vertical_flow"
        })
        n.add({
            type = "label",
            caption = q.technology.localised_name
        })

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

content.repopulate_static = function(player_index, anchor)
    populate_science_filters(player_index, anchor)
    populate_hide_categories(player_index, anchor)
end

content.repopulate_dynamic = function(player_index, anchor)
    populate_technology(player_index, anchor)
    populate_queue(player_index, anchor)
end

content.repopulate_all = function(player_index, anchor)
    content.repopulate_static(player_index, anchor)
    content.repopulate_dynamic(player_index, anchor)
end

content.repopulate_tech = function(player_index, anchor)
    populate_technology(player_index, anchor)
end

return content
