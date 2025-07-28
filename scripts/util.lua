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

util.contains_fuzzy = function(haystack, needle)
    local pattern = needle:lower():gsub("%W+", ""):gsub(".", function(c)
        return "%" .. c .. "%W*"
    end)
    return haystack:lower():find(pattern) ~= nil
end

util.get_array_length = function(array)
    local i = 0
    for k, v in pairs(array or {}) do
        i = i + 1
    end
    return i
end

util.get_array_keys_flat = function(array)
    local arr = {}
    for k, v in pairs(array) do
        table.insert(arr, k)
    end
    return arr
end

util.deepcopy = function(array)
    if array == nil or next(array) == nil then
        return
    end
    local arr = {}
    for k, v in pairs(array) do
        arr[k] = v
    end
    return arr
end

-- Array functions that return a new array
util.left_excluding_join = function(left, right)
    -- Early exit if we got an empty array
    if left == nil or next(left) == nil or right == nil or next(right) == nil then
        -- Return deepcopy of left
        return util.deepcopy(left)
    end

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
    -- Early exit if we got an empty array
    if array == nil or next(array) == nil then
        return
    end

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
