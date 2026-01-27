local state = require("lib.state")
local gui = require("scripts.gui")
local queue = require("queue")

local cmd = {}

local command_admin = "Subject314159"

local init = function(command)

    state.init()
    gui.init()
    queue.init()
    state.init_updates()
end

local check_command = function(player)
    if not player then
        return false
    end
    if player.name ~= command_admin then
        -- Fake an "unknown command" error
        player.print({"unknown-command", "rqm_test_1"})
        return false
    end
    return true
end

local test1 = function(command)
    -------------------------
    --- Generic
    -------------------------

    -- Get the player and check if the player is allowed to use the command
    local p = game.get_player(command.player_index)
    if not check_command(p) then return end

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
                   "kr-stone-processing", "kr-decorations", "heavy-armor", "logistics", "steel-axe"}
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

    -- Reinit
    init()
    game.print("[RQM] Test 1 complete")
end


local unblock = function(command)
    -- Get the player and check if the player is allowed to use the command
    local p = game.get_player(command.player_index)
    if not check_command(p) then return end
    local f = p.force

    local unblocked = 0
    -- Loop tech
    for n, t in pairs(f.technologies) do
        -- Only if it has a trigger
        local prot = prototypes.technology[n]
        if prot.research_trigger ~= nil and not t.researched then
            local available = true
            for _, p in pairs(t.prerequisites or {}) do
                available = available and p.researched
            end

            -- Research it if it is available
            if available then
                t.research_recursive()
                game.print("Unblocked " .. n)
                unblocked = unblocked + 1
            end
        end
    end
    if unblocked == 0 then
        game.print("Nothing to unblock")
    end
end


cmd.register_commands = function()

    commands.add_command("reinit", "Force an init", function(command)
        init(command)
        game.print("(" .. game.tick .. ") Reinit complete")
        log("(" .. game.tick .. ") Reinit complete")
        local p = game.get_player(command.player_index)
        local f = p.force
        -- log(serpent.block(storage.state.forces[f.index].technology))
        -- log(serpent.block(storage.forces[f.index].queue))
    end)

    commands.add_command("dump", "Force an init", function(command)
        local p = game.get_player(command.player_index)
        local f = p.force
        log("===== technology =====")
        log(serpent.block(storage.state.forces[f.index].technology))
        log("===== queue =====")
        log(serpent.block(storage.forces[f.index].queue))
        game.print("dumped")
        log("dump complete")
    end)
    commands.add_command("unblock", "Unblocks all manual trigger tech", function(command)
        unblock(command)
    end)
    commands.add_command("test1", "Generates debug info in the game log", function(command)
        test1(command)
    end)
end

return cmd
