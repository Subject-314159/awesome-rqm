local util = require('lib.util')
local const = require('lib.const')

local env = {}

---------------------------------------------------------------------------
-- Internal
---------------------------------------------------------------------------

local keys = {
    all_sciences = "all_sciences",
    tech_meta = "tech_meta"
}

---@param key string the identifier of the environment setting
local get = function(key)
    return storage.env[key]
end

---@param key string the identifier of the environment setting
---@param val any the value to be set
local set = function(key, val)
    storage.env[key] = val
end

---------------------------------------------------------------------------
-- all_sciences
---------------------------------------------------------------------------
-- Data model
-- local storage.env[all_sciences] = {"science-1", ...}

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
-- Data model
-- local storage.env[tech_meta] = {
--     [tech_name] = {
--         prototype = LuaTechnologyPrototype
--         has_trigger = bool,
--         is_infinte = bool,
--         has_successors = bool,
--         has_prerequisites = bool,
--         has_spoilable_science = bool,
--         sciences = {"science-1", ...},
--         research_effects = {"research-effect-1", ...},
--         research_prototypes = {"research-prototype-1", ...},
--         all_successors = {[tech_name] = bool, ...},
--         all_prerequisites = {[tech_name] = bool, ...},
--         -- blocking_prerequisites = {[tech_name] = bool, ...},

--     } , {...}
-- }

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
    local res = {}
    for TECH_NAME, T in pairs(prototypes.technology) do
        -- Init/get the empty tech array
        if not res[TECH_NAME] then
            res[TECH_NAME] = {}
        end
        local rcur = res[TECH_NAME]

        -- Copy standard properties
        rcur.prototype = T
        rcur.has_trigger = (T.research_trigger ~= nil)
        rcur.is_infinite = T.max_level >= 4294960000

        -- Effects and prototypes associated with this tech
        rcur.research_effects = {}
        rcur.research_prototypes = {}
        for _, effect in pairs(T.effects or {}) do
            rcur.research_effects[effect.type] = true
            local prototypes = get_prototypes(effect)
            for _, proto in pairs(prototypes) do
                rcur.research_prototypes[proto] = true
            end
        end

        -- Add sciences
        local s = {}
        rcur.has_spoilable_science = false
        for _, rui in pairs(T.research_unit_ingredients or {}) do
            table.insert(s, rui.name)
            local ITM = prototypes.item[rui.name]
            rcur.has_spoilable_science = rcur.has_spoilable_science or (ITM.get_spoil_ticks() > 0)
        end
        if #s > 0 then
            rcur.sciences = s
        end

        -- Init queue variable
        local queue

        -- Get first line successors
        queue = {}
        rcur.has_successors = false
        for _, SUC in pairs(T.successors or {}) do
            rcur.has_successors = true
            table.insert(queue, SUC)
        end

        -- Get all successors
        rcur.all_successors = {}
        while #queue > 0 do
            -- Get first next unvisited tech
            local TQ = table.remove(queue, 1)
            if rcur.all_successors[TQ.name] then
                goto continue
            end

            -- Mark current tech visited
            rcur.all_successors[TQ.name] = true

            -- Add all unvisited successors of current tech to the queue
            for _, SUC in pairs(TQ.successors or {}) do
                if not rcur.all_successors[SUC.name] then
                    table.insert(queue, SUC)
                end
            end

            ::continue::
        end

        -- Get first line prerequisites
        queue = {}
        rcur.has_prerequisites = false
        for _, PRE in pairs(T.prerequisites) do
            rcur.has_prerequisites = true
            table.insert(queue, PRE)
        end

        -- Get all prerequisites
        rcur.all_prerequisites = {}
        -- rcur.blocking_prerequisites = {}
        while #queue > 0 do
            -- Get first next unvisited tech
            local TQ = table.remove(queue, 1)
            if rcur.all_prerequisites[TQ.name] then
                goto continue
            end

            -- Mark current tech visited
            rcur.all_prerequisites[TQ.name] = true

            -- Add all unvisited predecessors of current tech to the queue
            for _, PRE in pairs(TQ.prerequisites or {}) do
                if not rcur.all_prerequisites[PRE.name] then
                    table.insert(queue, PRE)
                end
            end

            ::continue::
        end
    end

    -- Store the technology properties in environment
    set(keys.tech_meta, res)
end

env.get_all_tech_meta = function()
    return get(keys.tech_meta)
end

---@param tech_name the technology name
env.get_single_tech_meta = function(tech_name)
    local tm = get(keys.tech_meta)
    if tm and tm[tech_name] then
        return tm[tech_name]
    end
end

---------------------------------------------------------------------------
-- init
---------------------------------------------------------------------------

env.init = function()
    -- Init storage
    if not storage.env then
        storage.env = {}
    end

    -- Init each component
    init_sciences()
    init_tech_meta()
end

return env
