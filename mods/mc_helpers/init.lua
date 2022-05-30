mc_helpers = {}

---@public
---stringToColor
---Returns a random color based on input seed.
---Note that this function is not guaranteed to be the same on all systems.
---@param name string
---@return table containing alpha, red, green, and blue data
function mc_helpers.stringToColor(name)
    local seed = 0
    for c in name:gmatch(".") do
        seed = seed + string.byte(c)
    end

    math.randomseed(seed)

    local alpha = 255
    local red = math.random(255)
    local green = math.random(255)
    local blue = math.random(255)

    return { a = alpha, r = red, g = green, b = blue }
end

---@public
---Check whether or not a file exists.
---@param path string
---@return boolean whether or not the file at path exists.
function mc_helpers.fileExists(path)
    local f=io.open(path,"r")
    if f~=nil then io.close(f) return true else return false end
end

---@public
---Sorting comparison function for strings with numerals within them
---Returns true if the first detected numeral in a is less than the first detected numeral in b
---Fallbacks:
---If only one string contains a numeral, returns true if a contains the numeral, false if b contains the numeral
---If neither string has a numeral, returns the result of a < b (default sort)
---@param a The first string to be sorted
---@param b The second string to be sorted
---@return boolean
function mc_helpers.numSubstringCompare(a, b)
    local pattern = "^%D-(%d+)"
    local a_num = string.match(a, pattern)
    local b_num = string.match(b, pattern)

    if a_num and b_num then
        return tonumber(a_num) < tonumber(b_num)
    elseif not b_num and not a_num then
        return a < b
    else
        return a_num or false
    end
end

---@public
---Returns true if any of the values in the given table is equal to the value provided
---This function is not defined by Lua, so this should not overwrite a default function
---@param table The table to check
---@param val The value to check for
---@return boolean whether the value exists in the table
function table.has(table, val)
    if not table or not val then return false end
    for k,v in pairs(table) do
        if v == val then return true end
    end
    return false
end