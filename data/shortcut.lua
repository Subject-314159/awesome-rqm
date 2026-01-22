local ci
if settings.startup["rqm-startup_tech-shortcut-opens-rqm-instead"].value then
    ci = {
        type = "custom-input",
        name = "rqm_toggle_gui",
        key_sequence = "",
        linked_game_control = "open-technology-gui",
        consuming = "game-only"
    }
else
    ci = {
        type = "custom-input",
        name = "rqm_toggle_gui",
        key_sequence = "ALT + SHIFT + T"
    }
end

data:extend({ -- keybindings
ci, {
    type = "custom-input",
    name = "rqm_toggle_menu",
    key_sequence = "",
    linked_game_control = "toggle-menu",
    consuming = "none"
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
