local skeleton = {}

local const = require('const')
local util = require('util')

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
        name = "enable_toggle",
        switch_state = "right",
        right_label_caption = "Enable research queue manager"
    }, {
        type = "flow",
        style = "rqm_horizontal_flow_right"
    }}
}

local tabs = {
    -- Queue tabs
    type = "tabbed-pane",
    name = "queue_pane",
    style = "rqm_tabbed_pane",
    children = {{
        type = "tab",
        style = "rqm_tab",
        name = "tab_queue",
        tooltip = {"rqm-gui.tab-queue"},
        children = {{
            type = "sprite",
            style = "rqm_tab_icon",
            sprite = "rqm_queue_large"
        }}
    }, {
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
        -- }, {
        --     type = "tab",
        --     style = "rqm_tab",
        --     name = "tab_critical",
        --     tooltip = {"rqm-gui.tab-critical"},
        --     children = {{
        --         type = "sprite",
        --         style = "rqm_tab_icon",
        --         sprite = "rqm_critical_large"
        --     }}
        -- }, {
        --     type = "frame",
        --     name = "frame_critical",
        --     style = "rqm_tabbed_pane_frame",
        --     children = {{
        --         type = "scroll-pane",
        --         style = "rqm_vertical_scroll_pane",
        --         name = "pane_critical"
        --     }}
        -- }, {
        --     type = "tab",
        --     style = "rqm_tab",
        --     name = "tab_bookmarks",
        --     tooltip = {"rqm-gui.tab-bookmarks"},
        --     children = {{
        --         type = "sprite",
        --         style = "rqm_tab_icon",
        --         sprite = "rqm_bookmark_large"
        --     }}
        -- }, {
        --     type = "frame",
        --     name = "frame_bookmarks",
        --     style = "rqm_tabbed_pane_frame",
        --     children = {{
        --         type = "scroll-pane",
        --         style = "rqm_vertical_scroll_pane",
        --         name = "pane_bookmarks"
        --     }}
        -- }, {
        --     type = "tab",
        --     style = "rqm_tab",
        --     name = "tab_blacklist",
        --     tooltip = {"rqm-gui.tab-blacklist"},
        --     children = {{
        --         type = "sprite",
        --         style = "rqm_tab_icon",
        --         sprite = "rqm_blacklist_large"
        --     }}
        -- }, {
        --     type = "frame",
        --     name = "frame_blacklist",
        --     style = "rqm_tabbed_pane_frame",
        --     children = {{
        --         type = "scroll-pane",
        --         style = "rqm_vertical_scroll_pane",
        --         name = "pane_blacklist"
        --     }}
        -- }, {
        --     type = "tab",
        --     style = "rqm_tab",
        --     name = "tab_settings",
        --     tooltip = {"rqm-gui.tab-settings"},
        --     children = {{
        --         type = "sprite",
        --         style = "rqm_tab_icon",
        --         sprite = "rqm_settings_large"
        --     }}
        -- }, {
        --     type = "frame",
        --     name = "frame_settings",
        --     style = "rqm_tabbed_pane_frame",
        --     children = {{
        --         type = "scroll-pane",
        --         style = "rqm_vertical_scroll_pane",
        --         name = "pane_settings"
        --     }}
        -- }},
        -- mapping = {{"tab_queue", "frame_queue"}, {"tab_critical", "frame_critical"}, {"tab_bookmarks", "frame_bookmarks"},
        --            {"tab_blacklist", "frame_blacklist"}, {"tab_settings", "frame_settings"}}

    }},
    mapping = {{"tab_queue", "frame_queue"}}
}

---------------------------------------------------------------------------------------------------
--- Right pane content
---------------------------------------------------------------------------------------------------

-- Top section for allowed sciences
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
                --     type = "button",
                --     style = "rqm_button",
                --     caption = "produced"
                -- }, {
                --     type = "button",
                --     style = "rqm_button",
                --     caption = "unlocked"
                -- }, {
                type = "button",
                style = "rqm_button",
                caption = "all"
            }, {
                type = "button",
                style = "rqm_button",
                caption = "none"
            }, {
                type = "button",
                style = "rqm_button",
                caption = "invert"
            }}
        }}
    }, {
        type = "frame",
        name = "sci_tbl",
        style = "rqm_horizontal_shallow_frame",
        direction = "horizontal",
        children = {{
            type = "table",
            name = "allowed_science_table",
            column_count = 16
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
        caption = "Hide tech",
        style = "heading_2_label"
    }, {
        type = "flow",
        name = "hide_tech_flow",
        direction = "vertical"
    }, {
        type = "label",
        caption = "Show tech",
        style = "heading_2_label"
    }, {
        type = "radiobutton",
        caption = "All",
        state = true
        -- }, {
        --     type = "radiobutton",
        --     caption = "Recipe unlock",
        --     state = false
        -- }, {
        --     type = "radiobutton",
        --     caption = "Select category",
        --     state = false
        -- }, {
        --     type = "flow",
        --     direction = "vertical",
        --     style = "rqm_vflow_leftpadded",
        --     children = {{
        --         type = "flow",
        --         direction = "horizontal",
        --         children = {{
        --             type = "button",
        --             style = "rqm_button",
        --             caption = "all"
        --         }, {
        --             type = "button",
        --             style = "rqm_button",
        --             caption = "none"
        --         }, {
        --             type = "button",
        --             style = "rqm_button",
        --             caption = "invert"
        --         }}
        --     }, {
        --         type = "flow",
        --         name = "show_category_container",
        --         direction = "vertical"
        --     }}
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
            column_count = 3

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
            name = "left",
            direction = "vertical",
            children = {master_enable, tabs}
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

local structure2 = {
    type = "frame",
    style = "rqm_main_frame",
    name = "rqm_gui",
    caption = "MyGUI",
    direction = "horizontal",
    children = {{
        -- Left frame
        type = "frame",
        style = "rqm_main_left_frame",
        name = "left",
        direction = "vertical",
        -- children = {master_enable, tabs}
        children = {{
            type = "label",
            caption = "foo"
        }}
    }, {
        type = "line",
        direction = "vertical"
    }, {
        -- Right frame
        type = "flow",
        style = "rqm_main_right_flow",
        -- type = "frame",
        -- style = "rqm_inside_deep_frame",
        name = "right",
        direction = "vertical",
        children = {{
            type = "frame",
            style = "rqm_horizontal_shallow_frame",
            direction = "vertical",
            children = {{
                type = "label",
                style = "rqm_header",
                caption = "bar"
            }}
        }}
    }}
}

-- Builder
local build_recursive
build_recursive = function(parent, structure)
    -- For debugging
    -- game.print("Building: " .. (structure.name or "unknown"))
    if not structure.type then
        game.print("[RQM] Error: Got empty structure")
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
            game.print("[RQM] Error while generating children of " .. structure.name)
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

local refine = function(player_index, anchor)
    local elm = skeleton.get_child(anchor, "show_category_container")
    for k, v in pairs(const.categories) do
        local prop = {
            type = "checkbox",
            name = k,
            caption = k,
            tags = {
                rqm_on_click = true,
                handler = "show_category_checkbox"
            },
            state = false
        }
        elm.add(prop)
    end
end

local get_child_recursive
get_child_recursive = function(parent, target)
    if parent.name == target then
        return parent
    else
        for _, child in pairs(parent.children) do
            local res = get_child_recursive(child, target)
            if res then
                return res
            end
        end
    end
end

skeleton.get_child = function(anchor, name)
    local gui = anchor["rqm_gui"]
    if not gui then
        return
    end

    return get_child_recursive(gui, name)
end

-- Main entry point
skeleton.build = function(player_index, anchor)
    local player = game.get_player(player_index)
    if not player then
        return
    end

    -- Build the static frame and populate with static content
    build_recursive(anchor, structure)
    -- refine(player_index, anchor)

    -- Center the GUI and set as opened
    local main = anchor["rqm_gui"]
    main.auto_center = true
    player.opened = main

end

return skeleton
