local const = require("lib.const")

local tech = {}
----------------------------------------------------------------------------------------------------
-- Tech environment
----------------------------------------------------------------------------------------------------

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

tech.get_env = function()
    local tech_env = {}
    for name, t in pairs(prototypes.technology) do
        -- Init/get the empty tech array
        if not tech_env[name] then
            tech_env[name] = {}
        end
        local tn = tech_env[name]

        -- Copy standard properties
        tn.has_trigger = (t.research_trigger ~= nil)
        tn.research_trigger = t.research_trigger
        tn.is_infinite = t.max_level >= 4294960000
        tn.essential = t.essential
        tn.order = t.order
        tn.hidden = t.hidden

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

        -- Init queue variable for BFS
        local queue

        -- Get first line successors
        queue = {}
        tn.has_successors = false
        for s, _ in pairs(t.successors) do
            tn.has_successors = true
            table.insert(queue, s)
        end

        -- Get all successors
        tn.all_successors = {}
        while #queue > 0 do
            -- Get first next unvisited tech
            local tech = table.remove(queue, 1)
            if tn.all_successors[tech] then
                goto continue
            end
            local prot = prototypes.technology[tech]

            -- Mark current tech visited
            tn.all_successors[tech] = true

            -- Add all unvisited predecessors of current tech to the queue
            for s, _ in pairs(prot.prerequisites or {}) do
                if not tn.all_successors[s] then
                    table.insert(queue, s)
                end
            end

            ::continue::
        end

        -- Get first line prerequisites
        queue = {}
        tn.has_prerequisites = false
        for p, _ in pairs(t.prerequisites) do
            tn.has_prerequisites = true
            table.insert(queue, p)
        end

        -- Get all prerequisites
        tn.all_prerequisites = {}
        tn.blocking_prerequisites = {}
        while #queue > 0 do
            -- Get first next unvisited tech
            local tech = table.remove(queue, 1)
            if tn.all_prerequisites[tech] then
                goto continue
            end
            local prot = prototypes.technology[tech]

            -- Mark current tech visited
            tn.all_prerequisites[tech] = true

            -- Mark current tech as blocking
            if prot.research_trigger ~= nil then
                tn.blocking_prerequisites[tech] = true
            end

            -- Add all unvisited predecessors of current tech to the queue
            for s, _ in pairs(prot.prerequisites or {}) do
                if not tn.all_prerequisites[s] then
                    table.insert(queue, s)
                end
            end

            ::continue::
        end
    end

    return tech_env
end

return tech
