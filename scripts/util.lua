local util = {}

-- Array test functions
util.table_is_empty = function(tbl)
    for _, _ in pairs(tbl) do
        return false
    end
    return true
end

util.array_has_value = function(array, value)
    for k, v in pairs(array) do
        if v == value then
            return true
        end
    end
    return false
end

-- Array functions that return a new array
util.left_excluding_join = function(left, right)
    local result = {}
    for _, v in pairs(left) do
        if not util.array_has_value(right, v) then
            table.insert(result, v)
        end
    end
    return result
end

-- Array altering functions
util.array_append_array = function(left, right)
    for _, v in pairs(right) do
        table.insert(left, v)
    end
end

util.array_drop_value = function(array, value)
    local i = 1
    while i <= #array do
        if array[i] == value then
            table.remove(array, i)
        else
            i = i + 1
        end
    end
end

return util
