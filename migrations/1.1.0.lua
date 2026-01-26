--Skip if no storage.forces
if not storage or not storage.forces then return end

--Init new queue storage structure
local queue = require("scripts.queue")
queue.init()

--Migrate storage.forces.queue to storage.queue.forces
for i, prop in pairs(storage.forces) do
  -- TODO: implement migration
end
