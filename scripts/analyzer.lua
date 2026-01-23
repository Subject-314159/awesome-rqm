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

analyzer.get_labs_fill_rate = function(force_index)
  -- We need to figure out how well any science is filled in the labs
  -- It can be that 1 lab has 100 sciences, or 100 labs each 1 science
  -- The latter is more favorable
  local saf = get_force(force_index)
  local any_sciences = {} -- Array with sciences which have been seen at least once
  local science_total = {} -- Cummulative count of total # of sciences in all labs
  local science_present = {} -- How many ticks a science has been in any lab
  local tick_count = 0

  -- The grand total science item count over time in all labs
  local science_grand_total = {}

  -- The total number of labs for each science we consider to be sufficiently filled
  local science_present_in_labs = {}
  local total_labs = 0
  
  -- The total number of times a science has been registered in any lab
  local science_present_total_count = {} 
  local total_count = 0
  
  -- Go through each lab
  for _,lab_id in pairs(saf.all_labs or {}) do
    -- Skip if this lab has not been registering any ticks
    local saflc = saf.lab_content[lab_id]
    if not saflc or not saflc.ticks or #saflc.ticks == 0 then goto continue end
    
    -- Count each tick a science is present in this lab and count the total nr of sciences in this lab over time
    local lab_science_present_tick_count = {}
    local lab_science_item_count = {}
    local lab_tick_count = 0
    for _,tick in pairs(saflc.ticks or {}) do
      for science, count in pairs(saflc[tick] or {}) do
        lab_science_present_tick_count[science] = (lab_science_present_tick_count[science] or 0) + 1
        lab_science_item_count[science] = (lab_science_item_count[science] or 0) + count
      end
      lab_tick_count = lab_tick_count + 1
    end

    -- Skip this lab if it has no sciences at all or we don't have any tick content
    if next(lab_science_present_tick_count) == nil or lab_tick_count == 0 then goto continue end

    -- Process the tick counts
    local threshold = 50
    total_labs = total_labs + 1
    for science, count in pairs (lab_science_present_tick_count) do
      -- Count this lab if it has the science for a sufficient time
      if ((count * 100) / lab_tick_count) > threshold then
        science_present_in_labs[science] = science_present_in_labs[science] + 1
      end

      -- Add to the total number of ticks this science was present in any lab
      science_present_total_count[science] = (science_present_total_count[science] or 0) + 1
      -- total_count = total_count + 1

      -- Grand total of this science
      science_grand_total[science] = (science_grand_total[science] or 0) + (count or 0)
    end
    
    ::continue::
  end

  --Calculate the fill rate for each science
  -- Register rate is how many labs out of the total labs have seen this science at least once in the registered ticks
  -- Fill rate is how many labs we consider to be filled, i.e. the science is present in enough ticks
  local science_lab_register_rate = {}
  if total_labs > 0 then
    for science, count in pairs(science_present_in_labs) do
      science_lab_register_rate[science] = (count * 100) / total_labs
    end
  end
  local science_lab_fill_rate = {}
  if total_labs > 0 then
    for science, count in pairs(science_present_total_count) do
      science_lab_fill_rate[science] = (count * 100) / total_labs
    end
  end

  -- Calculate the grand total rate
  -- This calculation feels a bit skewed, because the science with the highest total count will be the 100% reference
  -- A science that was filled in the last few ticks does not yet have the opportunity to account for enough fill rate
  local science_grand_total_rate = {}
  local max_count = 0
  for science, count in pairs(science_grand_total) do
    if count > max_count then max_count = count end
  end
  if max_count > 0 then
    for science, count in pairs(science_grand_total) do
      science_grand_total_rate[science] = (count * 100) / max_count
    end
  end

  -- The return array
  local res = {
    science_lab_register_rate = science_lab_register_rate,
    science_lab_fill_rate = science_lab_fill_rate,
    science_grand_total_rate = science_grand_total_rate
  }
  
  -- For debugging
  log(serpent.block(res))
  
  return res
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
