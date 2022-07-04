networking = {}
networking.storage = minetest.get_mod_storage()
networking.ipv4_whitelist = minetest.deserialize(networking.storage:get_string("ipv4_whitelist"))
if not networking.ipv4_whitelist then
    -- Set a boolean for enabling the whitelist. Whitelist is disabled by default on startup to avoid players from automatically being kicked if not hosted locally.
    networking.storage:set_string("enabled", minetest.serialize(false))
    networking.storage:set_string("kick_message", "You are not authorized to join this server.")
    -- Initialize and set default whitelist ipv4 address 127.0.0.1 for singleplayer
    networking.ipv4_whitelist = {}
    networking.ipv4_whitelist["127.0.0.1"] = true
    networking.storage:set_string("ipv4_whitelist", minetest.serialize(networking.ipv4_whitelist))
end

function networking.parse(s,sep)
    local values = {}
    local sep = sep or " "
    local pattern = string.format("([^%s]+)", sep)
    string.gsub(s, pattern, function(c) values[#values + 1] = c end)
    return values
end

minetest.register_on_joinplayer(function(player) 
    local pname = player:get_player_name()
    local ipv4 = minetest.get_player_ip(pname)
    networking.ipv4_whitelist = minetest.deserialize(networking.storage:get_string("ipv4_whitelist"))
    local state = minetest.deserialize(networking.storage:get_string("enabled"))
    if not networking.ipv4_whitelist[ipv4] and state then
        minetest.kick_player(pname, networking.storage:get_string("kick_message"))
    end
end)

minetest.register_chatcommand("set_kick_message", {
	description = "Changes the networking kick message displayed on a failed attempt to join the server from a whitelisted IPV4 address.",
	privs = {server = true},
    params = "<message>",
	func = function(pname, message)
        minetest.chat_send_player(pname,"[networking] Success: Kick message updated to read '"..message.."'")
        networking.storage:set_string("kick_message", minetest.serialize(message))
	end
})

minetest.register_chatcommand("get_kick_message", {
	description = "Prints the networking kick message to player chat.",
	privs = {server = true},
	func = function(pname, message)
        local message = minetest.deserialize(networking.storage:get_string("kick_message"))
        minetest.chat_send_player(pname,"[networking] Kick message currently reads '"..message.."'")
	end
})

minetest.register_chatcommand("add_ipv4", {
	description = "Adds a single IPV4 address or a comma-separated list of IPV4 addresses to the whitelist.",
	privs = {server = true},
    params = "<ipv4_addresses>",
	func = function(pname, ipv4)
        -- Validate entry
        local addresses = networking.parse(ipv4,",")
        if #addresses == 0 then
            -- Empty entry
            minetest.chat_send_player(pname,"[networking] Error: Input was empty. Add an IPV4 address of the format '0.0.0.0' after the chat command and try again.")
        elseif #addresses == 1 then
            -- Single entry
            local octets = networking.parse(ipv4,".")
            if #octets == 4 then
                if tonumber(octets[1]) and tonumber(octets[2]) and tonumber(octets[3]) and tonumber(octets[4]) then
                    networking.ipv4_whitelist = minetest.deserialize(networking.storage:get_string("ipv4_whitelist"))
                    if not networking.ipv4_whitelist[ipv4] then
                        networking.ipv4_whitelist[ipv4] = true
                        networking.storage:set_string("ipv4_whitelist", minetest.serialize(networking.ipv4_whitelist))
                        minetest.chat_send_player(pname,"[networking] Success: Added IPV4 address at '"..ipv4.."'.")
                    else
                        minetest.chat_send_player(pname,"[networking] Warning: Input IPV4 address '"..ipv4.."' is already in the whitelist.")
                    end
                else
                    minetest.chat_send_player(pname,"[networking] Error: Expected four octets of format '0.0.0.0'. Check input '"..ipv4.."' and try again.")
                end
            else 
                minetest.chat_send_player(pname,"[networking] Error: Expected four octets of format '0.0.0.0'. Check input '"..ipv4.."' and try again.")
            end
        else
            -- Multiple entries
            networking.ipv4_whitelist = minetest.deserialize(networking.storage:get_string("ipv4_whitelist"))
            for _,address in pairs(addresses) do
                local octets = networking.parse(address,".")
                if #octets == 4 then
                    if tonumber(octets[1]) and tonumber(octets[2]) and tonumber(octets[3]) and tonumber(octets[4]) then
                        if not networking.ipv4_whitelist[address] then
                            networking.ipv4_whitelist[address] = true
                        else
                            minetest.chat_send_player(pname,"[networking] Warning: Input IPV4 address '"..address.."' is already in the whitelist.")
                        end
                    else
                        minetest.chat_send_player(pname,"[networking] Warning: Expected four octets of format '0.0.0.0'. Check input '"..address.."' and try again.")
                    end
                else
                    minetest.chat_send_player(pname,"[networking] Warning: Expected four octets of format '0.0.0.0' so skipping input '"..address.."'.")
                end
            end
            networking.storage:set_string("ipv4_whitelist", minetest.serialize(networking.ipv4_whitelist))
            minetest.chat_send_player(pname,"[networking] Success: Added comma-separated list of IPV4 addresses to the whitelist.")
        end
	end
})

minetest.register_chatcommand("add_ipv4_range", {
	description = "Adds a range of IPV4 addresses to the whitelist.",
	privs = {server = true},
    params = "<ipv4_address_start> <ipv4_address_end>",
	func = function(pname, input)
        -- Validate entry
        local addresses = networking.parse(input," ")
        if #addresses == 0 then
            -- Empty entry
            minetest.chat_send_player(pname,"[networking] Error: Input was empty. Add an IPV4 address range of the format '0.0.0.0 1.1.1.1' after the chat command and try again.")
        elseif #addresses == 1 then
            -- Missing entry
            minetest.chat_send_player(pname,"[networking] Error: Input was missing. Add an IPV4 address range of the format '0.0.0.0 1.1.1.1' after the chat command and try again.")
        else
            -- Completed entry
            local startRange = addresses[1]
            local endRange = addresses[2]
            local startOctets = networking.parse(startRange,".")
            local endOctets = networking.parse(endRange,".")
            if #startOctets == 4 and #endOctets == 4 then
                -- Validate all octets are integers
                if tonumber(startOctets[1]) and tonumber(startOctets[2]) and tonumber(startOctets[3]) and tonumber(startOctets[4]) and tonumber(endOctets[1]) and tonumber(endOctets[2]) and tonumber(endOctets[3]) and tonumber(endOctets[4]) then
                    minetest.chat_send_player(pname,"[networking] Starting to add range of IPV4 addresses to the whitelist, this may take a moment. Please wait for the success message.")
                    networking.ipv4_whitelist = minetest.deserialize(networking.storage:get_string("ipv4_whitelist"))
                    networking.counter = 0
                    if startOctets[1] == endOctets[1] then
                        if startOctets[2] == endOctets[2] then
                            if startOctets[3] == endOctets[3] then
                                if startOctets[4] == endOctets[4] then
                                    -- Start and end of range are equivalent, so there is only one IPV4 address to add in this range
                                    networking.ipv4_whitelist[startRange] = true
                                    networking.counter = networking.counter + 1
                                else
                                    -- First three octets are equivalent
                                    if startOctets[4] < endOctets[4] then
                                        for oct4=tonumber(startOctets[4]),tonumber(endOctets[4]),1 do
                                            local address = startOctets[1].."."..startOctets[2].."."..startOctets[3].."."..tostring(oct4)
                                            networking.ipv4_whitelist[address] = true
                                            networking.counter = networking.counter + 1
                                        end
                                    else
                                        minetest.chat_send_player(pname,"[networking] Error: Input '"..input.."' was misspecified. The start of the range comes after the end of the range. Check input and try again.")
                                    end
                                end
                            else
                                -- First two octets are equivalent
                                if tonumber(startOctets[3]) < tonumber(endOctets[3]) then
                                    for oct3=tonumber(startOctets[3]),tonumber(endOctets[3]),1 do
                                        if oct3 == tonumber(endOctets[3]) then lastOct = tonumber(endOctets[4]) else lastOct = 255 end
                                        for oct4=tonumber(startOctets[4]),lastOct,1 do
                                            local address = startOctets[1].."."..startOctets[2].."."..tostring(oct3).."."..tostring(oct4)
                                            networking.ipv4_whitelist[address] = true
                                            networking.counter = networking.counter + 1
                                        end
                                    end
                                else
                                    minetest.chat_send_player(pname,"[networking] Error: Input '"..input.."' was misspecified. The start of the range comes after the end of the range. Check input and try again.")
                                end
                            end
                        else
                            -- First octet is equivalent
                            if tonumber(startOctets[2]) < tonumber(endOctets[2]) then
                                for oct2=tonumber(startOctets[2]),tonumber(endOctets[2]),1 do
                                    for oct3=tonumber(startOctets[3]),lastOct3,1 do
                                        if oct3 == tonumber(endOctets[3]) then lastOct = tonumber(endOctets[4]) else lastOct = 255 end
                                        for oct4=tonumber(startOctets[4]),lastOct,1 do
                                            local address = startOctets[1].."."..tostring(oct2).."."..tostring(oct3).."."..tostring(oct4)
                                            networking.ipv4_whitelist[address] = true
                                            networking.counter = networking.counter + 1
                                        end
                                    end
                                end
                            else
                                minetest.chat_send_player(pname,"[networking] Error: Input '"..input.."' was misspecified. The start of the range comes after the end of the range. Check input and try again.")
                                return
                            end
                        end
                    else
                        -- No octets are equivalent
                        if tonumber(startOctets[1]) < tonumber(endOctets[1]) then
                            for oct1=tonumber(startOctets[1]),tonumber(endOctets[1]),1 do
                                for oct2=tonumber(startOctets[2]),tonumber(endOctets[2]),1 do
                                    for oct3=tonumber(startOctets[3]),tonumber(endOctets[3]),1 do
                                        if oct3 == tonumber(endOctets[3]) then lastOct = tonumber(endOctets[4]) else lastOct = 255 end
                                        for oct4=tonumber(startOctets[4]),lastOct,1 do
                                            local address = tostring(oct2).."."..tostring(oct2).."."..tostring(oct3).."."..tostring(oct4)
                                            networking.ipv4_whitelist[address] = true
                                            networking.counter = networking.counter + 1
                                        end
                                    end
                                end
                            end
                        else
                            minetest.chat_send_player(pname,"[networking] Error: Input '"..input.."' was misspecified. The start of the range comes after the end of the range. Check input and try again.")
                            return
                        end
                    end
                    networking.storage:set_string("ipv4_whitelist", minetest.serialize(networking.ipv4_whitelist))
                    minetest.chat_send_player(pname,"[networking] Success: Total of "..tostring(networking.counter).." IPV4 addresses in range of "..startRange.." to "..endRange.." were added to the whitelist.")
                else
                    minetest.chat_send_player(pname,"[networking] Error: Input '"..input.."' was misspecified. Add an IPV4 address range of the format '0.0.0.0 1.1.1.1' after the chat command and try again.")
                    return
                end
            else
                minetest.chat_send_player(pname,"[networking] Error: Input '"..input.."' was misspecified. Add an IPV4 address range of the format '0.0.0.0 1.1.1.1' after the chat command and try again.")
                return
            end
        end
	end
})

minetest.register_chatcommand("remove_ipv4", {
	description = "Removes a single IPV4 address or a comma-separated list of IPV4 addresses from the whitelist.",
	privs = {server = true},
    params = "<ipv4_addresses>",
	func = function(pname, ipv4)
        -- Validate entry
        local addresses = networking.parse(ipv4,",")
        if #addresses == 0 then
            -- Empty entry
            minetest.chat_send_player(pname,"[networking] Error: Input was empty. Add an IPV4 address of the format '0.0.0.0' after the chat command and try again.")
        elseif #addresses == 1 then
            -- Single entry
            local octets = networking.parse(ipv4,".")
            if #octets == 4 then
                if tonumber(octets[1]) and tonumber(octets[2]) and tonumber(octets[3]) and tonumber(octets[4]) then
                    networking.ipv4_whitelist = minetest.deserialize(networking.storage:get_string("ipv4_whitelist"))
                    if networking.ipv4_whitelist[ipv4] then
                        networking.ipv4_whitelist[ipv4] = nil
                        networking.storage:set_string("ipv4_whitelist", minetest.serialize(networking.ipv4_whitelist))
                        minetest.chat_send_player(pname,"[networking] Success: Removed IPV4 address at '"..ipv4.."'.")
                    else
                        minetest.chat_send_player(pname,"[networking] Warning: Did not find IPV4 address '"..ipv4.."' in the whitelist.")
                    end
                else
                    minetest.chat_send_player(pname,"[networking] Warning: Expected four octets of format '0.0.0.0'. Check input '"..ipv4.."' and try again.")
                end
            else 
                minetest.chat_send_player(pname,"[networking] Error: Expected four octets of format '0.0.0.0'. Check input '"..ipv4.."' and try again.")
            end
        else
            -- Multiple entries
            networking.ipv4_whitelist = minetest.deserialize(networking.storage:get_string("ipv4_whitelist"))
            for _,address in pairs(addresses) do
                local octets = networking.parse(address,".")
                if #octets == 4 then
                    if tonumber(octets[1]) and tonumber(octects[2]) and tonumber(octets[3]) and tonumber(octets[4]) then
                        if networking.ipv4_whitelist[address] then
                            networking.ipv4_whitelist[address] = nil
                            networking.storage:set_string("ipv4_whitelist", minetest.serialize(networking.ipv4_whitelist))
                            minetest.chat_send_player(pname,"[networking] Success: Removed IPV4 address at '"..address.."'.")
                        else
                            minetest.chat_send_player(pname,"[networking] Warning: Did not find IPV4 address '"..address.."' in the whitelist.")
                        end
                    else
                        minetest.chat_send_player(pname,"[networking] Warning: Expected four octets of format '0.0.0.0'. Check input '"..address.."' and try again.")
                    end
                else
                    minetest.chat_send_player(pname,"[networking] Error: Expected four octets of format '0.0.0.0'. Skipping input '"..address.."'.")
                end
            end
            networking.storage:set_string("ipv4_whitelist", minetest.serialize(networking.ipv4_whitelist))
            minetest.chat_send_player(pname,"[networking] Success: Removed comma-separated list of IPV4 addresses to the whitelist.")
        end
	end
})

minetest.register_chatcommand("clear_whitelist", {
	description = "Removes all IPV4 addresses from the whitelist except the default address 127.0.0.1 for singleplayer.",
	privs = {server = true},
	func = function(pname, _)
        networking.ipv4_whitelist = {}
        networking.ipv4_whitelist["127.0.0.1"] = true
        networking.storage:set_string("ipv4_whitelist", minetest.serialize(networking.ipv4_whitelist))
        minetest.chat_send_player(pname,"[networking] Success: Removed all IPV4 addresses from the whitelist.")
	end
})

minetest.register_chatcommand("dump_whitelist", {
	description = "Dumps all whitelisted IPV4s into chat.",
	privs = {server = true},
	func = function(pname, _)
        whitelist = minetest.deserialize(networking.storage:get_string("ipv4_whitelist"))
        minetest.chat_send_player(pname,"[networking] Whitelisted IPV4 addresses:")
        for ipv4,_ in pairs(whitelist) do
            minetest.chat_send_player(pname,"[networking] "..ipv4)
        end
	end
})

minetest.register_chatcommand("whitelist", {
	description = "Toggles the state of the whitelist between enabled and disabled.",
	privs = {server = true},
	func = function(pname, _)
        local state = minetest.deserialize(networking.storage:get_string("enabled"))
        if state then
            networking.storage:set_string("enabled", minetest.serialize(false))
            minetest.chat_send_player(pname,"[networking] Whitelist is now disabled.")
        else
            networking.storage:set_string("enabled", minetest.serialize(true))
            minetest.chat_send_player(pname,"[networking] Whitelist is now enabled.")
        end
	end
})