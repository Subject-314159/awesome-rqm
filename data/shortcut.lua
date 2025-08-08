data:extend({ -- keybindings
{
    type = "custom-input",
    name = "rqm_toggle_gui",
    key_sequence = "ALT + SHIFT + T"
}, {
    type = "custom-input",
    name = "rqm_focus_search",
    key_sequence = "",
    linked_game_control = "focus-search"
}, -- Shortcut buttons
{
    type = "shortcut",
    name = "rqm_shortcut",
    action = "lua",
    icon = "__awesome-rqm__/graphics/icons/shortcut-button.png",
    icon_size = 64,
    small_icon = "__awesome-rqm__/graphics/icons/shortcut-button.png",
    small_icon_size = 64
}})
