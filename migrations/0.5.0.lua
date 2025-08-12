local scheduler = require("__awesome-rqm__/scripts/scheduler")

for _, f in pairs(game.forces) do
    scheduler.recalculate_queue(f)
    scheduler.start_next_research(f)
end
