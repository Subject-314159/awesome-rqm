local env = require("model.env")
local state = require("model.state")
local tech = require("model.tech")
local queue = require("model.queue")
local gui = require("view.gui")

local cmd = {}

local command_admin = "Subject314159"

local init_player = function(player_index)
    if not storage then
        return
    end
    -- Init storage
    if not player_index then
        return
    end
    if not storage.players[player_index] then
        storage.players[player_index] = {}
    end

    -- Init each module
    state.init_player(player_index)
    gui.init_player(player_index)
end
local init_force = function(force_index)
    if not storage then
        return
    end
    -- Init storage
    if not storage.forces[force_index] then
        storage.forces[force_index] = {}
    end

    -- Init each module
    state.init_force(force_index)
    tech.init_force(force_index)
    queue.init_force(force_index)
    -- lab.init_force(force_index)
end

local init = function()
    -- Init storage
    if not storage then
        storage = {}
    end
    if not storage.forces then
        storage.forces = {}
    end
    if not storage.players then
        storage.players = {}
    end

    -- Init each module
    env.init()
    -- lab.init()

    -- Init each force
    for _, f in pairs(game.forces) do
        init_force(f.index)
    end

    -- Init each player
    for _, p in pairs(game.players) do
        init_player(p.index)
    end
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
    if not check_command(p) then
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
    if not check_command(p) then
        return
    end
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
    end)
    commands.add_command("dump", "Force an init", function(command)
        local p = game.get_player(command.player_index)
        local f = p.force
        log("===== technology =====")
        log(serpent.block(storage.state.forces[f.index].tech))
        log("===== queue =====")
        log(serpent.block(storage.forces[f.index].queue))
        game.print("Dump complete, see factorio-current.log")
        log("===== end dump =====")
    end)
    commands.add_command("unblock", "Unblocks all manual trigger tech", function(command)
        unblock(command)
    end)
    commands.add_command("test1", "Generates debug info in the game log", function(command)
        test1(command)
    end)
end

return cmd
