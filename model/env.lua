local env = {}

---------------------------------------------------------------------------
-- Internal
---------------------------------------------------------------------------

local keys = {
    all_sciences = "all_sciences",
    tech_meta = "tech_meta"
}

---@param key the identifier of the environment setting
local get = function(key)
    return storage.env[key]
end

---@param key the identifier of the environment setting
---@param val the value to be set
local set = function(key, val)
    storage.env[key] = val
end

---------------------------------------------------------------------------
-- all_sciences
---------------------------------------------------------------------------

local init_sciences = function()
    -- Create array of available sciences by looping through all labs and getting their inputs
    local sci = {}
    local prop = {
        filter = "type",
        type = "lab"
    }
    local labs = prototypes.get_entity_filtered({prop})

    for _, l in pairs(labs) do
        for _, s in pairs(l.lab_inputs) do
            util.insert_unique(sci, s)
        end
    end

    set(keys.all_sciences, sci)
end

env.get_all_sciences = function()
    return get(keys.all_sciences)
end

---------------------------------------------------------------------------
-- tech_meta
---------------------------------------------------------------------------

local get_allowed_prototype = function(proto)
    for _, prop in pairs(const.categories) do
        for _, pt in pairs(prop.prototypes or {}) do
            if pt == proto.type then
                return proto.type
            end
        end
    end
end


local get_prototypes = function(effect)
    local has_recipe = {
        ["change-recipe-productivity"] = true,
        ["unlock-recipe"] = true
    }
    local has_item = {
        ["give-item-modifier"] = true
    }
    local prots = {}
    local items = {}

    -- Get the items from the recipe
    if has_recipe[effect.type] then
        local r = prototypes.recipe[effect.recipe]
        for _, p in pairs(r.products) do
            if p.type == "item" then
                table.insert(items, p.name)
            end
        end
    end

    -- Get the item
    if has_item[effect.type] then
        table.insert(items, effect.item)
    end

    -- Search for the actual prototypes based on the items
    if #items > 0 then
        for _, itm in pairs(items) do
            -- Get the item prototype
            local ip = prototypes.item[itm]
            local proto = get_allowed_prototype(ip)

            if proto then
                table.insert(prots, proto)
            end

            -- Get the prototype of the place result
            if ip.place_result then
                table.insert(prots, ip.place_result.type)
            end
        end
    end

    -- Return the array with all prototypes associated with this effect
    return prots
end

local init_tech_meta = function()
    -- Store array of tech pre-/successors and blocking types
    local tech = {}
    for name, t in pairs(prototypes.technology) do
        -- Init/get the empty tech array
        if not tech[name] then
            tech[name] = {}
        end
        local tn = tech[name]

        -- Copy standard properties
        tn.has_trigger = (t.research_trigger ~= nil)
        tn.research_trigger = t.research_trigger
        tn.is_infinite = t.max_level >= 4294960000
        tn.essential = t.essential
        tn.order = t.order

        -- Effects and prototypes associated with this tech
        tn.research_effects = {}
        tn.research_prototypes = {}
        for _, effect in pairs(t.effects or {}) do
            tn.research_effects[effect.type] = true
            local prototypes = get_prototypes(effect)
            for _, proto in pairs(prototypes) do
                tn.research_prototypes[proto] = true
            end
        end

        -- Add sciences
        local s = {}
        for _, rui in pairs(t.research_unit_ingredients or {}) do
            table.insert(s, rui.name)
        end
        if #s > 0 then
            tn.sciences = s
        end

        -- Init queue variable
        local queue

        -- Get first line successors
        queue = {}
        tn.has_successors = false
        for _, suc in pairs(t.successors or {}) do
            tn.has_successors = true
            table.insert(queue, suc)
        end

        -- Get all successors
        tn.all_successors = {}
        while #queue > 0 do
            -- Get first next unvisited tech
            local tech = table.remove(queue, 1)
            if tn.all_successors[tech.name] then
                goto continue
            end

            -- Mark current tech visited
            tn.all_successors[tech.name] = true

            -- Add all unvisited successors of current tech to the queue
            for _, suc in pairs(tech.successors or {}) do
                if not tn.all_successors[suc.name] then
                    table.insert(queue, suc)
                end
            end

            ::continue::
        end

        -- Get first line prerequisites
        queue = {}
        tn.has_prerequisites = false
        for _, pre in pairs(t.prerequisites) do
            tn.has_prerequisites = true
            table.insert(queue, pre)
        end

        -- Get all prerequisites
        tn.all_prerequisites = {}
        tn.blocking_prerequisites = {}
        while #queue > 0 do
            -- Get first next unvisited tech
            local tech = table.remove(queue, 1)
            if tn.all_prerequisites[tech.name] then
                goto continue
            end

            -- Mark current tech visited
            tn.all_prerequisites[tech] = true

            -- Mark current tech as blocking
            if tech.research_trigger ~= nil then
                tn.blocking_prerequisites[tech.name] = true
            end

            -- Add all unvisited predecessors of current tech to the queue
            for _, suc in pairs(tech.prerequisites or {}) do
                if not tn.all_prerequisites[suc.name] then
                    table.insert(queue, suc)
                end
            end

            ::continue::
        end
    end

    -- Store the technology properties in environment
    set(keys.tech_meta, tech)
end

env.get_all_tech_meta = function()
    return get(keys.tech_meta)
end

---@param tech_name the technology name
env.get_single_tech_meta = function(tech_name)
    local tm = get(keys.tech_meta)
    if tm and tm[tech_name] then return tm[tech_name] end
end

---------------------------------------------------------------------------
-- init
---------------------------------------------------------------------------

env.init = function()
    -- Init storage
    if not storage.env then storage.env = {} end

    -- Init each component
    init_sciences()
    init_tech_meta()
end

return env