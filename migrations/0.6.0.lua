local state = require("lib.state")
local gui = require("scripts.gui")
local queue = require("scripts.queue")

-- Clear the storage because of complete rewrite, 
-- it might be that old saves still have some old metadata
-- which could mess up our code
storage = nil

-- Do a full init, this is required during migrations because some mods might do weird stuff and break our mod
state.init()
gui.init()
queue.init()

