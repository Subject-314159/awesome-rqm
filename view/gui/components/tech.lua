local const = require("lib.const")
local util = require("lib.util")
local state = require("model.state")
local tech = require("model.tech")
local analyzer = require("model.analyzer")

local gutil = require("view.gui.gutil")

local gctech = {}

local get_tech_icon = function(techtbl, xcur, enbl)
    local icn = techtbl.add({
        type = "sprite-button",
        name = xcur.technology.name,
        style = "rqm_tech_btn_available",
        sprite = "technology/" .. xcur.technology.name,
        tags = {
            rqm_on_click = true,
            handler = "show_technology_screen"
        },
        enabled = enbl
    })
    if xcur.technology.researched then
        icn.style = "rqm_tech_btn_researched"
    elseif xcur.available and xcur.meta.has_trigger then
        icn.style = "rqm_tech_btn_blocked"
    elseif not xcur.available then
        icn.style = "rqm_tech_btn_unavailable"
    end
end

local get_title = function(techtbl, xcur, enbl, player_index)
    local s = techtbl.add({
        type = "scroll-pane",
        style = "rqm_horizontal_tech_name_pane",
        direction = "horizontal",
        enabled = enbl
    })

    local n = s.add({
        type = "flow",
        direction = "vertical",
        style = "rqm_vertical_flow",
        enabled = enbl
    })

    -- The name
    local name = gutil.get_tech_name(player_index, xcur)
    n.add({
        type = "label",
        caption = name,
        enabled = enbl
    })
    local f = n.add({
        type = "flow",
        style = "rqm_horizontal_flow_nospacing",
        direction = "horizontal",
        enabled = enbl
    })
    -- The sciences
    local first = true
    for _, sci in pairs(xcur.meta.sciences or {}) do
        local ss = f.add({
            type = "sprite",
            sprite = "item/" .. sci,
            tooltip = {"item-name." .. sci}
        })
        -- If there are more than 8 sciences we need to add negative left margin to compensate for each science icon
        -- if not first and #t.research_unit_ingredients > 8 then
        if not first and #xcur.meta.sciences > 8 then
            ss.style.left_margin = (28 * (#xcur.meta.sciences - 8)) / -#xcur.meta.sciences
        end
        first = false
    end
    -- The unlock tech
    if xcur.meta.has_trigger then
        local rt = xcur.meta.prototype.research_trigger
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
            pr.tooltip = xcur.technology.name ..
                             " has unknown research trigger, please open a bug report in the mod portal"
            pr.sprite = "utility/danger_icon"
        end
        pr.enabled = enbl
        f.add(pr)
    end
end

local get_buttons = function(techtbl, xcur, enbl)
    -- Flow for the control buttons
    local fo = techtbl.add({
        type = "flow",
        direction = "horizontal",
        style = "rqm_horizontal_flow_padded",
        enabled = enbl
    })
    -- The add to queue buttons
    local f1 = fo.add({
        type = "flow",
        direction = "vertical",
        enabled = enbl
    })
    f1.add({
        type = "sprite-button",
        style = "rqm_icon_button",
        sprite = "rqm_arrow_up_small",
        hovered_sprite = "rqm_arrow_up_small_black",
        clicked_sprite = "rqm_arrow_up_small_black",
        tags = {
            rqm_on_click = true,
            handler = "add_queue_top",
            technology = xcur.technology.name
        },
        enabled = enbl
    })
    f1.add({
        type = "sprite-button",
        style = "rqm_icon_button",
        sprite = "rqm_arrow_down_small",
        hovered_sprite = "rqm_arrow_down_small_black",
        clicked_sprite = "rqm_arrow_down_small_black",
        tags = {
            rqm_on_click = true,
            handler = "add_queue_bottom",
            technology = xcur.technology.name
        },
        enabled = enbl
    })
end

gctech.populate = function(player_index, anchor)
    local p = game.get_player(player_index)
    local f = p.force
    local techtbl = gutil.get_child(anchor, "available_technology_table")
    if not techtbl then
        return
    end
    techtbl.clear()

    -- Get the state from storage or default settings
    local st = state.get_force_setting(f.index, "master_enable", const.default_settings.force.master_enable)
    local enbl = true
    if st == "left" then
        enbl = false
    end

    local tsx = analyzer.get_filtered_technologies_player(player_index)
    for _, xcur in pairs(tsx) do
        get_tech_icon(techtbl, xcur, enbl)
        get_title(techtbl, xcur, enbl, player_index)
        get_buttons(techtbl, xcur, enbl)
    end
end

return gctech
