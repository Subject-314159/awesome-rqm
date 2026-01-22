local util = require("lib.util")

local analyzer = {}

local get_force = function(force_index)
  local sa = storage.analyzer
  return sa.forces[force_index]
end

analyzer.tick_update = function()
  -- This function is a staggering update with a rate limit of 100 labs (currently hard coded)
  -- Go through all the labs for each force, read their content sciences, move on to the next force
  
  local sa = storage.analyzer
  --Early exit if there are no forces
  if not sa or not sa.all_forces or #sa.all_forces == 0 then return end

  --Reset the current force
  if sa.current_force == 0 then sa.current_force = #sa.all_forces end

  --Kick off the loop
  local count = 0
  while count < 100 do --TODO: Make this a mod setting
    --Get the force and lab count
    local saf = get_force(sa.all_forces[sa.current_force])
    

    -- Get the lab entity
    local lab_id = saf.all_labs[saf.current_lab]
    local lab = game.get_entity_by_unit_number(lab_id)

    -- Remove & skip this lab if it no longer exists
    if not lab or not lab.valid then
      table.remove(saf.all_labs, saf.current_lab)
      goto next_lab
    end

    -- Get the science inventory or skip if no inventory
    local inv = lab.get_inventory(defines.inventory.lab_input)
    if not inv then goto next_lab end

    --Init the current tick content array
    local saflc = saf.lab_content[lab_id]
    if not saflc[game.tick] then saflc[game.tick] = {} end
    local saflct = saflc[game.tick]

    --Read the lab content
    for _, c in pairs (inv.get_content()) do
      saflct[c.name] = (saflct[c.name] or 0) + (c.count or 0)
    end

    --Remember the tick and clean up old ones
    table.insert(saflc.ticks, game.tick)
    local max_time = 15*60*60 -- 15 minutes
    local max_len = 1000 -- 11 minutes at 1x/42 ticks
    for i = #saflc.ticks, 1, -1 do
      if i <= (#saflc.ticks - max_len) or saflc.ticks[i] < (game.tick - max_time) then
        table.remove(saflc.ticks, i)
      end
    end
    
    ::next_lab::
    -- Set the index for next lab
    saf.current_lab = saf.current_lab - 1
    
    --Reset the lab counter and next force if we had them all
    if saf.current_lab == 0 then
      saf.current_lab = #saf.all_labs

      --Set the index for next force
      sa.current_force = sa.current_force - 1
    end

    -- Update rate limiter counter
    count = count + 1

    -- Early exit the loop if we ran through everything before we hit the rate limit
    if sa.current_force == 0 then break end
  end
end

analyzer.register_lab = function(force_index, lab_id)
  local saf = get_force(force_index)
  if not util.array_has_value(saf.all_labs, lab_id) then table.insert(saf.all_labs, lab_id) end
  if not saf.lab_content[lab_id] then saf.lab_content[lab_id] = {} end
  local saflc = saf.lab_content[lab_id]
  if not saflc.ticks then saflc.ticks={} end
end

analyzer.init_force = function(force_index)
  --Get analyzer
  local sa = storage.analyzer

  -- Add unique force index to all forces array
  if not util.array_has_value(sa.all_forces,force_index) then table.insert(sa.all_forces,force_index) end

  -- Init the force
  if not sa.forces[force_index] then
      sa.forces[force_index] = {}
  end
  local saf = get_force(force_index)

  -- Init the labs
  if not saf.all_labs then saf.all_labs = {} end
  if not saf.labs then saf.labs = {} end
  for _,s in pairs(game.surfaces) do
    -- Find all labs on this surface belonging to this force
    local labs = s.find_entities_filtered({
        type="lab", force = force_index
      })
    --Register each lab
    for _,lab in pairs(labs) do
      analyzer.register_lab(force_index, lab.unit_number)
    end
  end
  saf.current_lab = 0
end

analyzer.init = function()
  if not storage.analyzer then storage.analyzer = {} end
  local sa = storage.analyzer
  if not sa.all_forces then sa.all_forces = {} end

  for _,f in pairs(game.forces) do
    analyzer.init_force(f.index)
  end
  sa.current_force = 0
end

return analyzer
