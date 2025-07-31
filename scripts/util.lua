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

util.array_has_all_values = function(array, values)
    for _, v in pairs(values) do
        if not util.array_has_value(array, v) then
            return false
        end
    end
    return true
end

local get_needle_clean = function(needle)
    local words = {}
    local pat = "[%w_-]+"
    -- local pat = "[^%s%p%-_]+"
    if type(needle) == "string" then
        needle = {needle}
    end
    for _, str in ipairs(needle) do
        for word in string.gmatch(str, pat) do
            table.insert(words, word:lower()) -- Might be string.lower(word)
        end
    end
    return words
end

local fuzzy_search_loop = function(needle_words, haystacks, threshold)
    local match_count = 0
    for _, word in ipairs(needle_words) do

        -- Loop through the haystacks
        for _, hay in pairs(haystacks) do
            -- Normalize the hay
            local hay_lc = hay:lower()

            -- Count each needle that matches the hay
            if string.find(hay_lc, word, 1, true) then
                match_count = match_count + 1

                -- Exit the haystack loop if we found a word, otherwise we might count words double
                break
            end
        end

        -- Check if the pass percentage is above the threshold
        local match_percent = (100 * match_count) / #needle_words
        if match_percent >= threshold then
            return true
        end
    end

    -- If we come here it means that none of our haystacks passed the threshold, so return false
    return false
end

util.fuzzy_search = function(needle, haystack, threshold)
    -- Normalize needle
    local needle_words = get_needle_clean(needle)

    -- Normalize haystack
    if type(haystack) == "string" then
        haystack = {haystack}
    end

    -- Normalize threshold
    if threshold == nil then
        threshold = 100
    end

    -- game.print("Searching for " .. serpent.line(needle_words) .. " in " .. serpent.line(haystack))
    -- Search the haystack
    return fuzzy_search_loop(needle_words, haystack, threshold)
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

util.insert_unique = function(array, prop)
    local exists = false
    for k, v in pairs(array) do
        if v == prop then
            exists = true
        end
    end
    if not exists then
        table.insert(array, prop)
    end
end

return util
