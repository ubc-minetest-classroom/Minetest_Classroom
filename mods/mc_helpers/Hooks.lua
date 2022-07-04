-- Ensures that we can use the server and Server usernames
minetest.register_on_prejoinplayer(function(name, ip)
    if (string.lower(name) == "server") then
        return "Invalid username: '" .. name .. "'. Please use a different name."
    end
end)