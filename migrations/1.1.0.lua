-- Migrate the old queue style to the new queue style
for _, f in pairs(game.forces) do
    -- Check if we have an old style queue
    if not storage or not storage.forces or not storage.forces[f.index] or not storage.forces[f.index].queue then
        goto continue
    end

    -- Init new style queue
    storage.forces[f.index].queue.queue = {}

    -- Migrate each tech to the new style queue
    for _, q in pairs(storage.forces[f.index].queue) do
        if q.technology_name then
            table.insert(storage.forces[f.index].queue.queue, q.technology_name)
        end
    end
    ::continue::
end
