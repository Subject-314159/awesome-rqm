local state = require("lib.state")
local gui = require("scripts.gui")
local queue = require("queue")

local test = {}

local command_admin = "Subject314159"

local init = function(command)

    state.init()
    gui.init()
    queue.init()
    state.init_updates()
end

local test1 = function(command)
    -------------------------
    --- Generic
    -------------------------

    -- Get the player and check if the player is allowed to use the command
    local p = game.get_player(command.player_index)
    if not p then
        return
    end
    if p.name ~= command_admin then
        -- Fake an "unknown command" error
        game.print({"unknown-command", "rqm_test_1"})
        return
    end

    -- Get the force
    local f = p.force
    if not f then
        return
    end

    -------------------------
    --- Specific
    -------------------------

    queue.clear(f)

    -- Set the initial techs as unlocked
    f.reset()
    local techs = {"automation-science-pack", "electronics", "steam-power", "automation", "kr-light-armor",
                   "kr-stone-processing"}
    for _, t in pairs(techs) do
        if f.technologies[t] then
            f.technologies[t].research_recursive()
        end
    end

    -- Add technology
    queue.add(f, "automobilism")
    queue.add(f, "oil-gathering")
    queue.add(f, "fluid-handling")
    queue.add(f, "plastics")

    -- Repopulate open GUIs
    -- gui.repopulate_open()

    state.request_gui_update(f)

    -- Redo the translations
    -- state.init()
    game.print("[RQM] Test 1 complete")
end

test.register_commands = function()

    commands.add_command("reinit", "Force an init", function(command)
        init(command)
        game.print("(" .. game.tick .. ") Reinit complete")
        log("(" .. game.tick .. ") Reinit complete")
    end)

    commands.add_command("dump", "Force an init", function(command)
        local p = game.get_player(command.player_index)
        local f = p.force
        log(serpent.block(storage.state.forces[f.index].technology))
        game.print("dumped")
        log("dump complete")
    end)
    commands.add_command("test1", "Generates debug info in the game log", function(command)
        test1(command)
    end)
end

return test
