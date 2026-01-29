local const = require('lib.const')
local util = require('lib.util')
local builder = {}

---------------------------------------------------------------------------------------------------
--- Left pane content
---------------------------------------------------------------------------------------------------
local master_enable = {
    -- Master toggle
    type = "frame",
    name = "enable_row",
    style = "rqm_subheader_frame",
    direction = "horizontal",
    children = {{
        type = "switch",
        name = "master_enable",
        right_label_caption = "Enable research queue manager", -- TODO: Make this a separate label with a separate on_click handler
        tags = {
            rqm_on_state_change = true,
            handler = "master_enable"
        }
    }, {
        type = "flow",
        style = "rqm_horizontal_flow_right"
    }}
}

-- Announcement level dropdown
local announcements = {}
for i, a in ipairs(const.announcements) do
    table.insert(announcements, {"rqm-force-settings.announce_" .. a})
end
local announcement_level = {
    type = "flow",
    direction = "horizontal",
    children = {{
        type = "label",
        caption = "Announcements"
    }, {
        type = "flow",
        style = "rqm_horizontal_flow_right",
        children = {{
            type = "drop-down",
            name = "announcement_level",
            items = announcements,
            tags = {
                rqm_on_state_change = true,
                handler = "announcement_level",
                setting_name = "announcement_level"
            }
        }}
    }}
}

-- Top left settings part
local generic_settings = {
    type = "frame",
    name = "enable_row",
    -- style = "rqm_subheader_frame",
    style = "rqm_allowed_science_frame",
    direction = "vertical",
    children = {master_enable, {
        type = "frame",
        name = "subsettings",
        style = "rqm_horizontal_shallow_frame",
        direction = "vertical",
        -- children = {announcement_level, {
        children = {{
            type = "flow",
            name = "force_settings_flow",
            direction = "vertical",
            children = {{
                type = "checkbox",
                name = "requeue_infinite_tech",
                caption = "Requeue infinite tech",
                state = const.default_settings.force.settings.requeue_infinite_tech,
                tags = {
                    rqm_on_state_change = true,
                    handler = "requeue_infinite_tech"
                }
            }}
        }}
    }}
}

-- Bottom left queue pane
local queue = {
    type = "frame",
    style = "inside_shallow_frame",
    name = "frame_queue",
    direction = "vertical",
    children = {{
        type = "scroll-pane",
        style = "rqm_vertical_scroll_pane",
        name = "pane_queue",
        direction = "vertical",
        children = {{
            type = "table",
            name = "table_queue",
            column_count = 6
        }}
    }}
}

---------------------------------------------------------------------------------------------------
--- Right pane content
---------------------------------------------------------------------------------------------------

local allowed_science = {
    type = "frame",
    style = "rqm_allowed_science_frame",
    name = "allowed_sciences",
    direction = "vertical",
    children = {{
        type = "frame",
        style = "rqm_subheader_frame",
        direction = "horizontal",
        children = {{
            type = "label",
            style = "heading_2_label",
            caption = "Allowed sciences"
        }, {
            type = "flow",
            style = "rqm_horizontal_flow_right",
            children = {{
                type = "button",
                style = "rqm_button",
                caption = "all",
                tags = {
                    rqm_on_click = true,
                    handler = "all_science"
                }
            }, {
                type = "button",
                style = "rqm_button",
                caption = "none",
                tags = {
                    rqm_on_click = true,
                    handler = "none_science"
                }
            }, -- {
            --     type = "button",
            --     style = "rqm_button",
            --     caption = "unlocked"
            -- }, {
            {
                type = "button",
                style = "rqm_button",
                caption = "invert",
                tags = {
                    rqm_on_click = true,
                    handler = "invert_science"
                }
            }} -- TODO: Add unlocked_science button
        }}
    }, {
        -- type = "frame",
        -- name = "sci_tbl",
        -- style = "rqm_horizontal_shallow_frame",
        -- direction = "horizontal",
        -- children = {{
        --     type = "scroll-pane",
        --     name = "sci_scroll",
        --     direction = "vertical",
        --     style = "rqm_vertical_scroll_pane",
        --     children = {{
        --         type = "table",
        --         name = "allowed_science_table",
        --         column_count = 14
        --     }}
        -- }}
        type = "scroll-pane",
        name = "sci_scroll",
        direction = "vertical",
        style = "rqm_vertical_scroll_pane",
        children = {{
            type = "table",
            name = "allowed_science_table",
            column_count = 14
        }}
    }}
}

-- Bottom left section for filter
local science_filter = {
    type = "frame",
    style = "rqm_filter_frame",
    name = "science_filter",
    direction = "vertical",
    children = {{
        type = "label",
        caption = "Hide by characteristic",
        style = "heading_2_label"
    }, {
        type = "flow",
        name = "hide_tech_flow",
        direction = "vertical"
    }, {
        type = "label",
        caption = "Filter by category",
        style = "heading_2_label"
    }, {
        type = "flow",
        name = "show_tech_flow",
        direction = "vertical"
    }}
}

-- Bottom right section for science list
local science_pane = {
    type = "frame",
    style = "rqm_technology_frame",
    name = "science_flow",
    direction = "vertical",
    children = {{
        type = "frame",
        name = "filter_row",
        style = "rqm_subheader_frame",
        direction = "horizontal",
        children = {{
            type = "label",
            style = "heading_2_label",
            caption = "Available technology"
        }, {
            type = "flow",
            style = "rqm_horizontal_flow_right",
            children = {{
                type = "textfield",
                name = "search_textfield",
                tags = {
                    rqm_on_change = true,
                    handler = "search_textfield"
                }
            }, {
                type = "sprite-button",
                style = "rqm_icon_button",
                name = "search_button",
                sprite = "utility/search"
            }}
        }}
    }, {
        type = "scroll-pane",
        style = "rqm_vertical_scroll_pane",
        name = "available_sciences",
        children = {{
            type = "table",
            name = "available_technology_table",
            column_count = 3,
            tags = {
                ignore_enable = true
            }

        }}
    }}
}

---------------------------------------------------------------------------------------------------
--- Master structure
---------------------------------------------------------------------------------------------------

local structure = {
    type = "frame",
    style = "rqm_main_frame",
    name = "rqm_gui",
    caption = "AwesomeRQM",
    direction = "horizontal",
    children = {{
        type = "flow",
        style = "rqm_horizontal_flow_spaced",
        name = "flow",
        children = {{
            -- Left frame
            type = "frame",
            style = "rqm_main_left_frame",
            -- style = "rqm_vertical_flow_spaced",
            name = "left",
            direction = "vertical",
            children = {generic_settings, queue}
        }, {
            type = "line",
            direction = "vertical"
        }, {
            -- Right frame
            type = "flow",
            -- style = "rqm_main_right_flow",
            style = "rqm_vertical_flow_spaced",
            name = "right",
            direction = "vertical",
            children = {allowed_science, {
                type = "flow",
                style = "rqm_horizontal_flow_spaced",
                name = "science_bottom",
                direction = "horizontal",
                children = {science_filter, science_pane}
            }}
        }}
    }}
}

-- Builder
local build_recursive
build_recursive = function(parent, structure)
    if not structure.type then
        game.print("[RQM] Error: Got empty structure, please open a bug report on the mod portal")
        return false
    end

    -- Build the properties array
    local prop = {}
    for k, v in pairs(structure) do
        if k ~= "children" then
            prop[k] = v
        end
    end

    -- Add the element
    local new = parent.add(prop)

    -- Recursive add elements
    for _, child in pairs(structure.children or {}) do
        if not build_recursive(new, child) then
            game.print("[RQM] Error while generating children of " .. structure.name ..
                           ", please open a bug report on the mod portal")
        end
    end

    -- Map tabs if any
    if structure.mapping then
        for _, map in pairs(structure.mapping) do
            new.add_tab(new[map[1]], new[map[2]])
        end
    end
    return true
end

-- Main entry point
builder.build = function(player_index, anchor)
    local player = game.get_player(player_index)
    if not player then
        return
    end

    -- Build the static frame and populate with static content
    build_recursive(anchor, structure)

    -- Center the GUI and set as opened
    local main = anchor["rqm_gui"]
    main.auto_center = true
    player.opened = main
end

return builder
