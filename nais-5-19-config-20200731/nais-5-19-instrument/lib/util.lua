local M = {}

M.bit = {[true] = "1", [false] = "0"}

function M.copy_table(source)
    local result = {}
    for k, v in pairs(source) do
        result[k] = v
    end
    return result
end

function M.deep_copy_table(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end -- if
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

function M.find_in_table(needle, haystack)
    for k, v in pairs(haystack) do
        if v == needle then
            return k
        end
    end
    return nil
end

function M.isnan(x)
    return not (x == x)
end

function M.nanval(x, default)
    if x == x then
        return x
    else
        return default
    end
end

function M.check_items(tbl, known_items, required_items)
    local missing = {}
    for k, v in pairs(required_items) do
        if tbl[v] == nil then
            table.insert(missing, v)
        end
    end

    local unknown = {}
    for k, v in pairs(tbl) do
        if M.find_in_table(k, known_items) == nil then
            table.insert(unknown, k)
        end
    end

    return {missing = missing, unknown = unknown}
end


return M
