-- Magic numbers
local outer_gui_height = 800
local left_frame_width = 450
local right_bottomleft_frame_width = 250
local right_bottomright_frame_width = 400
local tab_width = (left_frame_width) / 5
local tab_left_padding = (tab_width - 64) / 2

---------------------------------------------------------------------------------------------------
--- Main skeleton components
---------------------------------------------------------------------------------------------------
-- Flows
data.raw["gui-style"].default["rqm_horizontal_flow"] = {
    type = "horizontal_flow_style",
    -- horizontally_stretchable = "on"
    vertically_stretchable = "on"
}
data.raw["gui-style"].default["rqm_main_flow"] = {
    type = "horizontal_flow_style",
    horizontally_stretchable = "on",
    horizontal_spacing = 12
    -- vertically_stretchable = "on"
}

data.raw["gui-style"].default["rqm_horizontal_flow_right"] = {
    type = "horizontal_flow_style",
    parent = "rqm_horizontal_flow",
    horizontal_align = "right",
    horizontally_stretchable = "on"
}

data.raw["gui-style"].default["rqm_horizontal_flow_spaced"] = {
    type = "horizontal_flow_style",
    parent = "rqm_horizontal_flow",
    horizontal_spacing = 12
}

data.raw["gui-style"].default["rqm_vertical_flow"] = {
    type = "vertical_flow_style",
    -- vertically_stretchable = "on"
    horizontally_stretchable = "on"
}
data.raw["gui-style"].default["rqm_vertical_flow_spaced"] = {
    type = "vertical_flow_style",
    parent = "rqm_vertical_flow",
    vertical_spacing = 12
}
data.raw["gui-style"].default["rqm_vflow_leftpadded"] = {
    type = "vertical_flow_style",
    parent = "rqm_vertical_flow",
    left_padding = 18
}

-- Top level frame
data.raw["gui-style"].default["rqm_main_frame"] = {
    type = "frame_style",
    parent = "frame",
    horizontal_flow_style = data.raw["gui-style"].default["rqm_main_flow"],
    horizontally_stretchable = "on",
    -- width = 1200,
    height = outer_gui_height
}

data.raw["gui-style"].default["rqm_inside_deep_frame"] = {
    type = "frame_style",
    parent = "inside_deep_frame",
    horizontally_stretchable = "on",
    vertically_stretchable = "on"
}

-- Sub section frames
data.raw["gui-style"].default["rqm_shallow_frame"] = {
    type = "frame_style",
    parent = "inside_shallow_frame",
    padding = 10
}
data.raw["gui-style"].default["rqm_horizontal_shallow_frame"] = {
    type = "frame_style",
    parent = "rqm_shallow_frame",
    horizontally_stretchable = "on"
}
data.raw["gui-style"].default["rqm_vertical_shallow_frame"] = {
    type = "frame_style",
    parent = "rqm_shallow_frame",
    vertically_stretchable = "on"
}

-- Scroll panes

data.raw["gui-style"].default["rqm_vertical_scroll_pane"] = {
    type = "scroll_pane_style",
    parent = "scroll_pane",
    horizontally_stretchable = "on"
}

---------------------------------------------------------------------------------------------------
--- Subheader
---------------------------------------------------------------------------------------------------

data.raw["gui-style"].default["rqm_subheader_frame"] = {
    type = "frame_style",
    horizontally_stretchable = "on",
    vertical_align = "center"
}

---------------------------------------------------------------------------------------------------
--- Tabbed pane (left)
---------------------------------------------------------------------------------------------------
---
data.raw["gui-style"].default["rqm_main_left_frame"] = {
    type = "frame_style",
    parent = "rqm_inside_deep_frame",
    width = left_frame_width
}

data.raw["gui-style"].default["rqm_tabbed_pane_frame"] = {
    type = "frame_style",
    parent = "rqm_shallow_frame",
    horizontally_stretchable = "on",
    vertically_stretchable = "on",
    left_margin = 8,
    right_margin = 8,
    top_margin = 3,
    bottom_margin = 3
}

data.raw["gui-style"].default["rqm_tabbed_pane"] = {
    type = "tabbed_pane_style",
    parent = "filter_tabbed_pane",
    horizontally_stretchable = "on"
}
data.raw["gui-style"].default["rqm_tab"] = {
    type = "tab_style",
    parent = "filter_group_tab",
    horizontally_stretchable = "on",
    width = tab_width,
    left_padding = tab_left_padding
}

data.raw["gui-style"].default["rqm_tab_scroll_pane"] = {
    type = "scroll_pane_style",
    parent = "scroll_pane",
    horizontally_stretchable = "on",
    vertically_stretchable = "on",
    always_draw_borders = true
}

data.raw["gui-style"].default["rqm_tab_icon"] = {
    type = "image_style",
    parent = "image",
    horizontally_stretchable = "off",
    vertically_stretchable = "off",
    horizontally_squashable = "off",
    vertically_squashable = "off",
    stretch_image_to_widget_size = false
}

data.raw["gui-style"].default["rqm_queue_prio_textfield"] = {
    type = "textbox_style",
    parent = "textbox",
    horizontal_align = "right",
    width = 32
}

---------------------------------------------------------------------------------------------------
--- Search (right)
---------------------------------------------------------------------------------------------------

data.raw["gui-style"].default["rqm_main_right_flow"] = {
    type = "vertical_flow_style",
    parent = "rqm_vertical_flow",
    horizontally_stretchable = "on"
}
-- Top frame
data.raw["gui-style"].default["rqm_allowed_science_frame"] = {
    type = "frame_style",
    parent = "inside_deep_frame",
    horizontally_stretchable = "on"
}
-- Bottom left frame
data.raw["gui-style"].default["rqm_filter_frame"] = {
    type = "frame_style",
    parent = "rqm_vertical_shallow_frame",
    width = right_bottomleft_frame_width
}
-- Bottom right frame
data.raw["gui-style"].default["rqm_technology_frame"] = {
    type = "frame_style",
    parent = "rqm_inside_deep_frame",
    width = right_bottomright_frame_width
}

-- Content
data.raw["gui-style"].default["rqm_technology_table"] = {
    type = "table_style",
    parent = "table",
    horizontally_stretchable = "on"
}

---------------------------------------------------------------------------------------------------
--- Generic elements
---------------------------------------------------------------------------------------------------

data.raw["gui-style"].default["rqm_button"] = {
    type = "button_style",
    parent = "frame_button",
    font = "heading-2",
    default_font_color = {0.9, 0.9, 0.9},
    minimal_width = 0,
    height = 24,
    right_padding = 8,
    left_padding = 8
}

data.raw["gui-style"].default["rqm_icon_button"] = {
    type = "button_style",
    parent = "rqm_button",
    width = 24,
    height = 24,
    padding = 0
}

data.raw["gui-style"].default["rqm_header"] = {
    type = "label_style",
    parent = "heading_2_label",
    horizontally_stretchable = "stretch_and_expand"
}

---------------------------------------------------------------------------------------------------
--- Technology elements
---------------------------------------------------------------------------------------------------

local function default_glow(tint_value, scale_value)
    return {
        position = {200, 128},
        corner_size = 8,
        tint = tint_value,
        scale = scale_value,
        draw_type = "outer"
    }
end
local default_shadow_color = {0, 0, 0, 0.35}
local default_shadow = default_glow(default_shadow_color, 0.5)
local tech_btn_height = 64
local tech_btn_width = tech_btn_height * 0.85

data.raw["gui-style"].default["rqm_image_science"] = {
    type = "image_style",
    width = 12,
    height = 12,
    padding = 0
}

data.raw["gui-style"].default["rqm_tech_btn"] = {
    type = "button_style",
    height = tech_btn_height,
    width = tech_btn_width,
    padding = 0
}

local default_available = {
    base = {
        position = {296, 136},
        corner_size = 8
    },
    shadow = default_shadow
}
local elevated_available = {
    base = {
        position = {312, 136},
        corner_size = 8
    },
    shadow = default_shadow
}
local highlighted_available = {
    base = {
        position = {330, 136},
        corner_size = 8
    },
    shadow = default_shadow
}

data.raw["gui-style"].default["rqm_tech_btn_available"] = {
    type = "button_style",
    parent = "rqm_tech_btn",
    default_graphical_set = default_available,
    hovered_graphical_set = elevated_available,
    selected_hovered_graphical_set = elevated_available,
    clicked_graphical_set = elevated_available,
    selected_graphical_set = elevated_available,
    selected_clicked_graphical_set = elevated_available,
    disabled_graphical_set = default_available,
    highlighted_graphical_set = highlighted_available
}

data.raw["gui-style"].default["rqm_tech_btn_conditional"] = {
    type = "button_style",
    parent = "rqm_tech_btn",
    default_graphical_set = {
        base = {
            position = {296, 153},
            corner_size = 8
        },
        shadow = default_shadow
    },
    hovered_graphical_set = {
        base = {
            position = {312, 153},
            corner_size = 8
        },
        shadow = default_shadow
    },
    selected_hovered_graphical_set = {
        base = {
            position = {312, 153},
            corner_size = 8
        },
        shadow = default_shadow
    },
    clicked_graphical_set = {
        base = {
            position = {312, 153},
            corner_size = 8
        },
        shadow = default_shadow
    },
    selected_graphical_set = {
        base = {
            position = {312, 153},
            corner_size = 8
        },
        shadow = default_shadow
    },
    selected_clicked_graphical_set = {
        base = {
            position = {312, 153},
            corner_size = 8
        },
        shadow = default_shadow
    },
    disabled_graphical_set = {
        base = {
            position = {296, 153},
            corner_size = 8
        },
        shadow = default_shadow
    },
    highlighted_graphical_set = {
        base = {
            position = {330, 153},
            corner_size = 8
        },
        shadow = default_shadow
    }
}

data.raw["gui-style"].default["rqm_tech_btn_researched"] = {
    type = "button_style",
    parent = "rqm_tech_btn",
    default_graphical_set = {
        base = {
            position = {296, 187},
            corner_size = 8
        },
        shadow = default_shadow
    },
    hovered_graphical_set = {
        base = {
            position = {312, 187},
            corner_size = 8
        },
        shadow = default_shadow
    },
    selected_hovered_graphical_set = {
        base = {
            position = {312, 187},
            corner_size = 8
        },
        shadow = default_shadow
    },
    clicked_graphical_set = {
        base = {
            position = {312, 187},
            corner_size = 8
        },
        shadow = default_shadow
    },
    selected_graphical_set = {
        base = {
            position = {312, 187},
            corner_size = 8
        },
        shadow = default_shadow
    },
    selected_clicked_graphical_set = {
        base = {
            position = {312, 187},
            corner_size = 8
        },
        shadow = default_shadow
    },
    disabled_graphical_set = {
        base = {
            position = {296, 187},
            corner_size = 8
        },
        shadow = default_shadow
    },
    highlighted_graphical_set = {
        base = {
            position = {330, 187},
            corner_size = 8
        },
        shadow = default_shadow
    }
}

data.raw["gui-style"].default["rqm_tech_btn_unavailable"] = {
    type = "button_style",
    parent = "rqm_tech_btn",
    default_graphical_set = {
        base = {
            position = {296, 170},
            corner_size = 8
        },
        shadow = default_shadow
    },
    hovered_graphical_set = {
        base = {
            position = {312, 170},
            corner_size = 8
        },
        shadow = default_shadow
    },
    selected_hovered_graphical_set = {
        base = {
            position = {312, 170},
            corner_size = 8
        },
        shadow = default_shadow
    },
    clicked_graphical_set = {
        base = {
            position = {312, 170},
            corner_size = 8
        },
        shadow = default_shadow
    },
    selected_graphical_set = {
        base = {
            position = {312, 170},
            corner_size = 8
        },
        shadow = default_shadow
    },
    selected_clicked_graphical_set = {
        base = {
            position = {312, 170},
            corner_size = 8
        },
        shadow = default_shadow
    },
    disabled_graphical_set = {
        base = {
            position = {296, 170},
            corner_size = 8
        },
        shadow = default_shadow
    },
    highlighted_graphical_set = {
        base = {
            position = {330, 170},
            corner_size = 8
        },
        shadow = default_shadow
    }
}

data.raw["gui-style"].default["rqm_tech_btn_blocked"] = {
    type = "button_style",
    parent = "rqm_tech_btn",
    default_graphical_set = {
        base = {
            position = {347, 204},
            corner_size = 8
        },
        shadow = default_shadow
    },
    hovered_graphical_set = {
        base = {
            position = {363, 204},
            corner_size = 8
        },
        shadow = default_shadow
    },
    selected_hovered_graphical_set = {
        base = {
            position = {363, 204},
            corner_size = 8
        },
        shadow = default_shadow
    },
    clicked_graphical_set = {
        base = {
            position = {363, 204},
            corner_size = 8
        },
        shadow = default_shadow
    },
    selected_graphical_set = {
        base = {
            position = {363, 204},
            corner_size = 8
        },
        shadow = default_shadow
    },
    selected_clicked_graphical_set = {
        base = {
            position = {363, 204},
            corner_size = 8
        },
        shadow = default_shadow
    },
    disabled_graphical_set = {
        base = {
            position = {347, 204},
            corner_size = 8
        },
        shadow = default_shadow
    },
    highlighted_graphical_set = {
        base = {
            position = {381, 204},
            corner_size = 8
        },
        shadow = default_shadow
    }
}

