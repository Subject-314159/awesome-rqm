local content = {}

local skeleton = require('gui-skeleton')
local util = require('util')

local populate_science_filters = function(player, anchor)
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
        local sprop = {
            type = "sprite-button",
            sprite = "item/" .. s
        }
        scitbl.add(sprop)
    end
end

local populate_technology = function(player, anchor)
    local techtbl = skeleton.get_child(anchor, "available_technology_table")
    if not techtbl then
        return
    end
    techtbl.clear()

    for _, t in pairs(player.force.technologies) do
        if t.enabled then
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
            local n = techtbl.add({
                type = "flow",
                direction = "vertical"
            })
            n.add({
                type = "label",
                caption = t.localised_name
            })
            local f = n.add({
                type = "flow",
                direction = "horizontal"
            })
            -- Add sciences
            for _, ing in pairs(t.research_unit_ingredients) do
                f.add({
                    type = "sprite",
                    style = "rqm_image_science",
                    sprite = "item/" .. ing.name
                })
            end
            -- Add unlock tech
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
            local fo = techtbl.add({
                type = "flow",
                direction = "horizontal"
            })
            local f1 = fo.add({
                type = "flow",
                direction = "vertical"
            })
            local f2 = fo.add({
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
            f2.add({
                type = "sprite-button",
                style = "rqm_icon_button",
                sprite = "rqm_bookmark_small",
                tags = {
                    rqm_on_click = true,
                    handler = "add_queue_top",
                    technology = t.name
                }
            })
            f2.add({
                type = "sprite-button",
                style = "rqm_icon_button",
                sprite = "rqm_blacklist_small",
                tags = {
                    rqm_on_click = true,
                    handler = "add_queue_bottom",
                    technology = t.name
                }
            })
        end
    end
end

local populate_queue = function(player, anchor)
    local tblq = skeleton.get_child(anchor, "table_queue")
    if not tblq then
        game.print("ERR: No queue table found")
        return
    end
    tblq.clear()

    local gf = storage.forces[player.force.index]
    if not gf or not gf.queue then
        tblq.add({
            type = "label",
            caption = "Queue new research to start AwesomeRQM"
        })
        return
    end

    for _, q in pairs(gf.queue) do
        -- Prio listbox
        tblq.add({
            type = "textfield",
            name = q.technology.name .. "_textfield",
            style = "rqm_queue_prio_textfield",
            lose_focus_on_confirm = true
        })

        -- Buttons
        local fl = tblq.add({
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
        local spr
        if player.force.current_research == q.technology.name then
            spr = "rqm_progress_small"
        else
            spr = "rqm_plus_small"
        end
        tblq.add({
            type = "sprite",
            sprite = "rqm_progress_small"
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
        tblq.add({
            type = "label",
            caption = q.technology.name
        })

        -- Trash bin
        tblq.add({
            type = "sprite-button",
            style = "rqm_icon_button",
            sprite = "rqm_bin_small",
            tags = {
                rqm_on_click = true,
                handler = "remove_from_queue",
                technology = q.technology.name
            }
        })
    end
end

content.repopulate_all = function(player_index, anchor)
    -- Get the player
    local player = game.get_player(player_index)
    if not player then
        return
    end

    -- TODO: replace with player_index because we might need to retrieve storage settings
    populate_science_filters(player, anchor)
    populate_technology(player, anchor)
    populate_queue(player, anchor)
end

return content
