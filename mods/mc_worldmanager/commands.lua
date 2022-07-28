-- All the functionality from these commands will added to a realm book.
-- These commands are currently just for testing


local commands = {}

minetest.register_chatcommand("localPos", {
    privs = {
        teacher = true,
    },
    func = function(name, param)
        local player = minetest.get_player_by_name(name)
        local requestedRealm = Realm.GetRealmFromPlayer(player)

        if (requestedRealm == nil) then
            return false, "Player is not listed in a realm OR current realm has been deleted; Try teleporting to a different realm and then back..."
        end

        local position = requestedRealm:WorldToLocalPosition(player:get_pos())
        return true, "Your position in the local space of realm " .. param .. " is x: " .. position.x .. " y: " .. position.y .. " z: " .. position.z
    end,
    help = "Get your local position in the current realm",
})

commands["new"] = {
    func = function(name, params)
        local realmName = tostring(params[1])
        if (realmName == "" or realmName == "nil") then
            realmName = "Unnamed Realm"
        end
        local sizeX = tonumber(params[2])
        if (sizeX == nil or sizeX == 0) then
            sizeX = 40
        end
        local sizeY = tonumber(params[3])
        if (sizeY == nil or sizeY == 0) then
            sizeY = 40
        end
        local sizeZ = tonumber(params[4]) or 40
        if (SizeZ == nil or SizeZ == 0) then
            SizeZ = 40
        end
        local newRealm = Realm:New(realmName, { x = sizeX, y = sizeY, z = sizeZ })
        newRealm:CreateGround()
        newRealm:CreateBarriersFast()

        return true, "created new realm with ID: " .. newRealm.ID
    end,
    help = "realm new [name] ([<sizeX>] [<sizeY>] [<sizeZ>]) - Create a new realm", }

commands["delete"] = {
    func = function(name, params)
        local realmID = params[1]

        if (realmID == nil) then
            return false, "No realm ID specified"
        end

        if (realmID == mc_worldManager.spawnRealmID) then
            return false, "Cannot delete the spawn realm."
        end

        local requestedRealm = Realm.GetRealm(tonumber(realmID))
        if (requestedRealm == nil) then
            return false, "Requested realm of ID: " .. tostring(realmID) .. " does not exist."
        end
        requestedRealm:Delete()
    end,
    help = "realm delete <realmID> - Delete a realm", }

commands["list"] = {
    func = function(name, params)
        minetest.chat_send_player(name, "Realm Name : Realm ID")
        for i, t in pairs(Realm.realmDict) do
            minetest.chat_send_player(name, t.Name .. " : " .. t.ID)
        end

        return true
    end,
    help = "realm list - List all realms", }

commands["info"] = {
    func = function(name, params)
        local realmID = params[1]
        local requestedRealm = Realm.GetRealm(tonumber(realmID))
        if (requestedRealm == nil) then
            return false, "Requested realm does not exist."
        end

        local spawn = requestedRealm.SpawnPoint
        local startPos = requestedRealm.StartPos
        local endPos = requestedRealm.EndPos

        return true, "Realm " .. realmID .. " has a spawn point of "
                .. "x:" .. tostring(spawn.x) .. " y:" .. tostring(spawn.y) .. " z:" .. tostring(spawn.z)
                .. "; startPos of "
                .. "x:" .. tostring(startPos.x) .. " y:" .. tostring(startPos.y) .. " z:" .. tostring(startPos.z)
                .. "; endPos of "
                .. "x:" .. tostring(endPos.x) .. " y:" .. tostring(endPos.y) .. " z:" .. tostring(endPos.z)
    end,
    help = "realm info <realmID> - Get info about a realm", }

commands["tp"] = {
    privs = { teleport = true },
    func = function(name, params)
        local realmID = params[1]
        local requestedRealm = Realm.GetRealm(tonumber(realmID))

        if (not minetest.player_exists(name)) then
            return false, "Player: " .. tostring(name) .. " could not be found"
        end

        if (requestedRealm == nil) then
            return false, "Requested realm of ID: " .. tostring(realmID) .. " does not exist."
        end

        local player = minetest.get_player_by_name(name)
        local success, reason = requestedRealm:TeleportPlayer(player)

        return success, reason
    end,
    help = "realm tp <realmID> - Teleport to a realm.", }

commands["walls"] = {
    func = function(name, params)
        local realmID = params[1]
        local requestedRealm = Realm.GetRealm(tonumber(realmID))
        if (requestedRealm == nil) then
            return false, "Requested realm of ID: " .. tostring(realmID) .. " does not exist."
        end

        if (params[2] ~= nil and params[2] == "fast") then
            requestedRealm:CreateBarriersFast()
        else
            requestedRealm:CreateBarriers()
        end

        return true, "created walls in realm: " .. tostring(realmID)
    end,
    help = "realm walls <realmID> [<fast>] - Create walls in a realm", }

commands["gen"] = {
    func = function(name, params)

        if (not mc_helpers.isNumber(params[1])) then
            if (params[1] ~= nil and params[1] == "list") then


                minetest.chat_send_player(name, "Generator Key")

                local heightmapGen = Realm.WorldGen.GetHeightmapGenerators()
                for k, v in pairs(heightmapGen) do
                    minetest.chat_send_player(name, v)
                end

                minetest.chat_send_player(name, "==============================")

                minetest.chat_send_player(name, "Decorator Key")

                local terrainDecorator = Realm.WorldGen.GetTerrainDecorator()
                for k, v in pairs(terrainDecorator) do
                    minetest.chat_send_player(name, v)
                end

                return true, "Listed an terrain generators and decorators."
            end
        end

        local realmID = params[1]
        local requestedRealm = Realm.realmDict[tonumber(realmID)]
        if (requestedRealm == nil) then
            return false, "Requested realm of ID: " .. tostring(realmID) .. " does not exist."
        end

        local seaLevel = math.floor((requestedRealm.EndPos.y - requestedRealm.StartPos.y) * 0.4) + requestedRealm.StartPos.y
        Debug.log("Sea level:" .. seaLevel)

        local heightGen = params[2]
        local decGen = params[3]

        local seed = tonumber(params[5])
        if (seed == nil) then
            seed = math.random(1, 999999999)
        end

        local seaLevel = requestedRealm.StartPos.y
        if (params[4] == "" or params[4] == nil) then
            seaLevel = seaLevel + 30
        else
            seaLevel = seaLevel + tonumber(params[4])
        end

        if (heightGen == "" or heightGen == nil) then
            heightGen = "default"
        end

        if (requestedRealm:GenerateTerrain(seed, seaLevel, heightGen, decGen) == false) then
            return false, "Failed to generate terrain"
        end

        Debug.log("Creating barrier...")
        requestedRealm:CreateBarriersFast()



        return true, "Generated terrain in realm: " .. tostring(realmID) .. " using seed " .. tostring(seed)
    end,
    help = "realm gen <list> | (<realmID> <heightGenKey> [<terrainDecKey>] ([<seaLevel>] [<seed>]) - Generate a realm", }

commands["regen"] = {
    func = function(name, params)
        local realmID = params[1]
        local requestedRealm = Realm.realmDict[tonumber(realmID)]
        if (requestedRealm == nil) then
            return false, "Requested realm of ID: " .. tostring(realmID) .. " does not exist."
        end

        local seaLevel = math.floor((requestedRealm.EndPos.y - requestedRealm.StartPos.y) * 0.4) + requestedRealm.StartPos.y
        Debug.log("Sea level:" .. seaLevel)

        local seed = requestedRealm:get_data("worldSeed")
        local seaLevel = requestedRealm:get_data("worldSeaLevel")
        local heightGen = requestedRealm:get_data("worldMapGenerator")
        local decGen = requestedRealm:get_data("worldDecoratorName")

        if (seed == nil or seed == "nil") then
            return false, "Realm does not have any saved seed information."
        end

        if (heightGen == nil or heightGen == "") then
            return false, "Realm does not have any saved height generator information. Please try to manually regenerate world with gen command and seed " .. tostring(seed)
        end

        if (decGen == nil or decGen == "") then
            return false, "Realm does not have any saved decorator information. Please try to manually regenerate world with gen command, seed " .. tostring(seed) .. " and height generator name " .. tostring(heightGen)
        end

        requestedRealm:GenerateTerrain(seed, seaLevel, heightGen, decGen)

        Debug.log("Creating barrier...")
        requestedRealm:CreateBarriersFast()

        return true
    end,
    help = "realm regen <realmID> - Regenerates the terrain of a realm.", }

commands["seed"] = { func = function(name, params)
    local realmID = params[1]
    local requestedRealm = Realm.GetRealm(tonumber(realmID))
    if (requestedRealm == nil) then
        return false, "Requested realm of ID: " .. tostring(realmID) .. " does not exist."
    end

    local seed = requestedRealm:get_data("worldSeed")

    return true, "World Seed for Realm: " .. tostring(seed)
end,
                     help = "realm seed <realmID> - Get the seed of a realm.", }

commands["schematic"] = {
    func = function(name, params)
        if (params[1] == "list") then
            table.remove(params, 1)

            minetest.chat_send_player(name, "Key : Filepath")
            for i, t in pairs(schematicManager.schematics) do
                minetest.chat_send_player(name, i .. " : " .. t)
            end
            return true
        elseif (params[1] == "save") then
            table.remove(params, 1)
            local realmID = params[1]
            local requestedRealm = Realm.GetRealm(tonumber(realmID))

            if (requestedRealm == nil) then
                return false, "Requested realm of ID: " .. tostring(realmID) .. " does not exist."
            end

            local schemName = tostring(params[2])
            Debug.log(schemName)

            local subparam = tostring(params[3])

            if (subparam == "" or subparam == "nil") then
                subparam = "old"
            end

            local path = requestedRealm:Save_Schematic(schemName, name, subparam)
            return true, "Saved realm with ID " .. realmID .. " at path: " .. path
        elseif (params[1] == "load") then
            table.remove(params, 1)
            local realmName = params[1]
            if (realmName == "" or realmName == nil) then
                realmName = "Unnamed Realm"
            end

            local key = params[1]
            if (key == nil) then
                key = ""
            end

            local schematic, config = schematicManager.getSchematic(key)

            if (config == nil) then
                return false, "schematic key: " .. tostring(key) .. " config file has not been registered with the system."
            end

            local newRealm = Realm:NewFromSchematic(realmName, key)
            return true, "creat[ing][ed] new realm with name: " .. newRealm.Name .. "and ID: " .. newRealm.ID .. " from schematic with key " .. key
        else
            return false, "unknown subcommand. Try realm schematic list | realm schematic save | realm schematic load"
        end
    end }

commands["setspawn"] = {
    func = function(name, params)
        local player = minetest.get_player_by_name(name)

        local requestedRealm = Realm.GetRealmFromPlayer(player)

        local position = requestedRealm:WorldToLocalPosition(player:get_pos())

        requestedRealm:UpdateSpawn(position)

        return true, "Updated spawnpoint for realm with ID: " .. requestedRealm.ID
    end,
    help = "realm setspawn <realmID> - Set the spawnpoint of a realm.", }

commands["setspawnrealm"] = {
    func = function(name, params)
        local realmID = params[1]
        local requestedRealm = Realm.GetRealm(tonumber(realmID))
        if (requestedRealm == nil) then
            return false, "Requested realm of ID: " .. tostring(realmID) .. " does not exist."
        end

        local success = mc_worldManager.SetSpawnRealm(requestedRealm)

        if (success) then
            return true, "Updated the spawn realm to realm with ID: " .. realmID
        else
            return false, "something went wrong... could not update the spawn realm."
        end
    end,
    help = "realm setspawnrealm <realmID> - Sets the spawn realm to the realm with the given ID." }

commands["category"] = {
    func = function(name, params)
        local subcommand = tostring(params[1])

        if (string.lower(subcommand) == "set") then
            local realmID = tonumber(params[2])
            local requestedRealm = Realm.GetRealm(tonumber(realmID))
            if (requestedRealm == nil) then
                return false, "Requested realm of ID:" .. tostring(realmID) .. " does not exist."
            end

            local category = tostring(params[3])

            requestedRealm:setCategoryKey(category)
            return true, "Updated category for realm with ID: " .. realmID .. " to " .. category
        elseif (string.lower(subcommand) == "list") then

            minetest.chat_send_player(name, "=======================")
            minetest.chat_send_player(name, "Valid Realm Categories")
            minetest.chat_send_player(name, "=======================")
            local categories = Realm.getRegisteredCategories()
            for key, value in pairs(categories) do
                minetest.chat_send_player(name, value)
            end
            minetest.chat_send_player(name, "=======================")
            return true, "Listed all valid realm categories."
        else
            return false, "unknown subcommand. Try realm category set <category>"
        end


    end,
    help = "realm category (set <realmID> <category>) | (list) - Set the category of a realm or list all valid categories.",
}

commands["consolidate"] = {
    func = function(name, params)
        Realm.consolidateEmptySpace()
        Realm.SaveDataToStorage()
        return true, "consolidated realms"
    end,
    help = "consolidate realm placement information." }

commands["help"] = {
    func = function(name, params)

        local subcommand = params[1]

        if (subcommand ~= nil and subcommand ~= "") then

            local helpString
            if (commands[subcommand].help == "" or commands[subcommand].help == nil) then
                helpString = "No help available for this command."
            else
                helpString = commands[subcommand].help
            end
            return true, helpString
        end

        local helpString = ""
        for k, v in pairs(commands) do
            helpString = helpString .. k .. " | "
        end
        return true, helpString
    end,
    help = "help [command] - displays help for a command. If no command is specified, displays a list of commands."
}

commands["define"] = {
    func = function(name, params)
        -- this is really hacky, we should come up with a better way to do this...

        local name = tostring(params[1])
        local pos1X = tonumber(params[2])
        local pos1Y = tonumber(params[3])
        local pos1Z = tonumber(params[4])
        local pos2X = tonumber(params[5])
        local pos2Y = tonumber(params[6])
        local pos2Z = tonumber(params[7])

        if (name == nil or pos1X == nil or pos1Y == nil or pos1Z == nil or pos2X == nil or pos2Y == nil or pos2Z == nil) then
            return false, "missing command parameters"
        end

        local pos1 = { x = pos1X, y = pos1Y, z = pos1Z }
        local pos2 = { x = pos2X, y = pos2Y, z = pos2Z }
        local spawnPos = { x = (pos1.x + pos2.x) / 2, y = pos2.y - 5, z = (pos1.z + pos2.z) / 2 }

        local newRealm = {
            Name = name,
            ID = Realm.realmCount + 1,
            StartPos = pos1,
            EndPos = pos2,
            SpawnPoint = spawnPos,
            PlayerJoinTable = nil,
            PlayerLeaveTable = nil,
            RealmDeleteTable = nil,
            MetaStorage = { }
        }

        Realm.realmCount = newRealm.ID
        Realm:Restore(newRealm)
    end }

commands["privs"] = {
    func = function(name, params)
        local operation = tostring(params[1])
        local realmID = tonumber(params[2])
        local privilege = tostring(params[3])

        if (operation == "nil" or operation == "") then
            return false, "Incorrect parameter... Missing realm privilege operation. Execute 'realm help privs' for help."
        end

        if (operation == "help") then
            return true, "execute 'realm help privs' for help."
        end

        if (realmID == nil or realmID == "") then
            return false, "Incorrect parameter... Missing realm ID. Execute 'realm help privs' for help."
        end

        local requestedRealm = Realm.realmDict[realmID]
        if (requestedRealm == nil) then
            return false, "Requested realm of ID: " .. tostring(realmID) .. " does not exist."
        end

        if (operation == "list") then

            if (requestedRealm.Permissions ~= nil) then
                for i, t in pairs(requestedRealm.Permissions) do
                    minetest.chat_send_player(name, "- " .. i)
                end
            else
                minetest.chat_send_player(name, "No realm privileges have been set.")
            end

            return true, "command executed succesfully"
        end

        if (privilege == "nil" or privilege == "") then
            return false, "Incorrect parameter... Missing realm privilege to add or revoke. Execute 'realm help privs' for help."
        end

        if (operation == "grant") then

            if (minetest.check_player_privs(name, privilege) == false) then
                return false, "Unable to add privilege: " .. privilege .. " to realm" .. tostring(realmID) .. " as you do not hold this privilege."
            end
            local privsTable = {}
            privsTable[privilege] = true

            local success, invalidPrivs = requestedRealm:UpdateRealmPrivilege(privsTable)

            if (not success) then
                return false, "Unable to add privilege: " .. privilege .. " to realm" .. tostring(realmID) .. " as it has not been whitelisted."
            end

            return true, "Added permission: " .. privilege .. " to realm " .. tostring(realmID)
        elseif (operation == "revoke") then

            local privsTable = {}
            privsTable[privilege] = false

            requestedRealm:UpdateRealmPrivilege(privsTable)
            return true, "Removed permission: " .. privilege .. " from realm " .. tostring(realmID)
        end
    end,
    help = "realm privs (grant | list | revoke) <realmID> <privilege>"
}

commands["players"] = {
    func = function(name, params)


        if (params[1] == "list") then
            local realmID = params[2]
            local requestedRealm = Realm.GetRealm(tonumber(realmID))
            if (requestedRealm == nil) then
                return false, "Requested realm of ID: " .. tostring(realmID) .. " does not exist."
            end

            local realmPlayerList = requestedRealm:get_tmpData("Inhabitants")

            if (realmPlayerList == nil) then
                return false, "no players found in realm player list."
            end

            Debug.log(minetest.serialize(realmPlayerList))

            for k, v in pairs(realmPlayerList) do
                minetest.chat_send_player(name, k)
            end

            return true, "listed all players in realm."
        elseif (params[1] == "scan") then
            Realm.ScanForPlayerRealms()
            return true, "re-associated players with realms."

        end

        return false, "unknown sub-command."
    end,
    help = "players <list | scan> - lists all players in a realm. 'players scan' will re-associate players with realms."
}

commands["blocks"] = {
    func = function(name, params)
        if (params[1] == "teleporter") then
            local instanced = false
            local temp = false
            local realmID = 0

            local realmName = nil
            local schematic = nil

            local count = params[2]

            if (mc_helpers.isNumber(tostring(params[3]))) then
                realmID = tonumber(params[3])
            elseif (string.lower(tostring(params[3])) == "true") then
                instanced = true
            end

            if (string.lower(tostring(params[4])) == "true") then
                temp = true
            end

            realmName = tostring(params[5])
            schematic = tostring(params[6])

            if (schematic == "" or schematic == "nil") then
                schematic = nil
            elseif (schematicManager.getSchematic(schematic) == nil) then
                return false, "schematic " .. tostring(schematic) .. " does not exist."
            end

            local is = mc_worldManager.GetTeleporterItemStack(count, instanced, temp, realmID, realmName, schematic)

            local player = minetest.get_player_by_name(name)

            player:get_inventory():add_item("main", is)
            return true, "added teleporter to inventory."
        end

        return false, "For help, execute /realm help blocks."
    end,
    help = "realm blocks <block> <count> (<instanced: true | false> | <realmID>) <temporary: true | false> <realmName> <schematic>"

}



commands["clean"] = {
    func = function(name, params)
        local realmID = tonumber(params[1])
        local requestedRealm = Realm.GetRealm(realmID)
        if (requestedRealm == nil) then
            return false, "Requested realm of ID: " .. tostring(realmID) .. " does not exist."
        end

        requestedRealm:Clean()
        return true, "cleaned realm " .. tostring(realmID)
    end,
    help = "realm clean <realmID> -- replaces any unknown block with air."
}

commands["coordinates"] = {
    func = function(name, params)
        local operation = tostring(params[1])
        local format = tostring(params[2])

        local playerRealm = Realm.GetRealmFromPlayer(minetest.get_player_by_name(name))

        if (operation == "set") then
            if (format == "UTM") then
                if (utmInfo == nil) then
                    utmInfo = { easting = tonumber(params[3]), northing = tonumber(params[4]), zone = tonumber(params[5]), utm_is_north = tostring(params[6]) }
                end
                playerRealm:set_data("UTMInfo", utmInfo)
                return true
            end
            return false, "invalid format."

        elseif (operation == "get") then
            local rawPos = minetest.get_player_by_name(name):getpos()
            local pos

            if (format == "world") then
                pos = rawPos
            elseif (format == "local" or format == "nil") then
                pos = playerRealm.WorldToLocalPosition(rawPos)
            elseif (format == "grid") then
                pos = Realm.worldToGridSpace(rawPos)
            elseif (format == "utm") then
                pos = playerRealm:WorldToUTM(rawPos)
            elseif (format == "latlong") then
                pos = playerRealm:WorldToLatLong(rawPos)
            else
                return false, "unknown format: " .. tostring(format)
            end

            minetest.chat_send_player(name, "Format: X: " .. tostring(pos.x) .. " Y: " .. tostring(pos.y) .. " Z: " .. tostring(pos.z))
            return true, "command executed succesfully"

        elseif (operation == "hud") then
            if (mc_worldManager.positionTextFunctions[format] ~= nil) then
                pmeta:set_string("positionHudMode", format)
                return true, "enabled position hud element for format " .. format .. "."
            elseif (format == "nil" or format == "none") then
                pmeta:set_string("positionHudMode", "")
                mc_worldManager.RemovePositionHud(minetest.get_player_by_name(name))
                return true, "disabled position hud element."
            end
            return false, "invalid format."
        end

        return false, "unknown command parameters."
    end,
    help = "realm coordinates <set | get | hud> <format (world, grid, local, utm, latlong)>"
}

commands["data"] = {
    func = function(name, params)
        local operation = tostring(params[2])
        local realmID = tonumber(params[1])
        local realm = Realm.GetRealm(realmID)
        if (realm == nil) then
            return false, "realm " .. tostring(realmID) .. " does not exist."
        end
        if (operation == "get") then
            local data = realm:get_data(tostring(params[3]))
            if (data == nil) then
                return false, "data " .. tostring(params[3]) .. " does not exist."
            end
            minetest.chat_send_player(name, "Data: " .. tostring(data))
            return true, "command executed succesfully"
        elseif (operation == "set") then
            realm:set_data(tostring(params[3]), tostring(params[4]))
            return true, "command executed succesfully"
        elseif (operation == "dump") then
            local data = realm.MetaStorage
            minetest.chat_send_player(name, "Data: " .. tostring(minetest.serialize(data)))
            return true, "command executed succesfully"
        end
        return false, "unknown sub-command."
    end,
    help = "realm data <get | set> <realmID> <dataName> <dataValue>"
}


minetest.register_chatcommand("realm", {
    params = "Subcommand Realm ID Option",
    func = function(name, param)
        local params = mc_helpers.split(param, " ")
        local subcommand = params[1]
        table.remove(params, 1)

        if (commands[subcommand] ~= nil) then
            if (commands[subcommand].privs == nil) then
                commands[subcommand].privs = { teacher = true }
            end
            local has, missing = minetest.check_player_privs(name, commands[subcommand].privs)
            if not has then
                local missingPermsString = ""
                for k, v in pairs(missing) do
                    missingPermsString = missingPermsString .. v .. ", "
                end

                return false, "You do not have permission to use this command. Missing command(s): " .. missingPermsString
            end

            return commands[subcommand].func(name, params)
        else
            return false, "Unknown subcommand. Use 'realm help' for a list of sub-commands."
        end
    end,
})

-- Gets called when a command is called, before it is handled by the engine / lua runtime.
minetest.register_on_chatcommand(function(name, command, params)


    if (command == "grantme") then
        local privTable = mc_helpers.split(params, ", ")
        mc_worldManager.grantUniversalPriv(minetest.get_player_by_name(name), privTable)
        return false -- we must return false so that the regular grant command proceeds.
    elseif (command == "revokeme") then
        local privTable = mc_helpers.split(params, ", ")
        mc_worldManager.revokeUniversalPriv(minetest.get_player_by_name(name), privTable)
        return false -- we must return false so that the regular grant command proceeds.
    end


    -- Gets called when grant / revoke is called. We're using this to add permissions that are granted onto the universalPrivs table.

    if (command == "grant" or command == "revoke") then
        local privsTable = mc_helpers.split(params, ", ")
        local tmpTable = mc_helpers.split(table.remove(privsTable, 1), " ")

        local name = tmpTable[1]
        table.insert(privsTable, tmpTable[2])
        tmpTable = nil

        if (not minetest.player_exists(name)) then
            return false -- we must return false so that the regular grant command proceeds. Error text is handled there.
        end

        if (name == nil or name == "" or privsTable == nil) then
            return false -- we must return false so that the regular grant command proceeds. Error text is handled there.
        end

        if (command == "grant") then
            mc_worldManager.grantUniversalPriv(minetest.get_player_by_name(name), privsTable)
        else
            mc_worldManager.revokeUniversalPriv(minetest.get_player_by_name(name), privsTable)
        end
    end

    return false
end)


-- We could have also done minetest.override_chatcommand; but I want complete control
minetest.unregister_chatcommand("teleport")

minetest.register_chatcommand("teleport", {
    privs = {
        teleport = true,
    },
    description = "Teleport yourself or a specified player to a realm or another player.",
    params = "<realm ID> | <target player> | (<player name> <realm ID>) | (<player name> <target player name>) | (<realm ID> <local x pos> <local y pos> <local z pos>)",
    func = function(name, param)

        local function teleport(name, othername)

            if (not minetest.player_exists(name)) then
                return false, "Player " .. tostring(name) .. " could not be found..."
            end

            if (not minetest.player_exists(othername)) then
                return false, "Player " .. tostring(othername) .. " could not be found..."
            end

            local player = minetest.get_player_by_name(name)
            local otherPlayer = minetest.get_player_by_name(othername)
            local pmeta = otherPlayer:get_meta()
            local realmID = pmeta:get_int("realm")

            local requestedRealm = Realm.realmDict[realmID]

            if (requestedRealm == nil) then
                return false, "Player " .. tostring(othername) .. " is not listed in a realm OR current realm has been deleted; Try teleporting to a different realm and then back..."
            end

            requestedRealm:TeleportPlayer(player)
            local pos = otherPlayer:get_pos()
            player:set_pos(pos)
            return true, "Teleported to " .. tostring(othername) .. " in realm " .. tostring(realmID)
        end

        local paramTable = mc_helpers.split(param, " ")
        if (paramTable == nil) then
            paramTable = { param }
        end

        if (mc_helpers.isNumber(paramTable[1]) and mc_helpers.isNumber(paramTable[2]) and mc_helpers.isNumber(paramTable[3]) and mc_helpers.isNumber(paramTable[4])) then
            local realmID = paramTable[1]
            local requestedRealm = Realm.realmDict[tonumber(realmID)]

            if (not minetest.player_exists(name)) then
                return false, "Player: " .. tostring(name) .. " could not be found"
            end

            if (requestedRealm == nil) then
                return false, "Requested realm of ID: " .. tostring(realmID) .. " does not exist."
            end

            local player = minetest.get_player_by_name(name)

            local position = { x = paramTable[2], y = paramTable[3], z = paramTable[4] }
            local worldPosition = requestedRealm:LocalToWorldPosition(position)

            if (not requestedRealm:ContainsCoordinate(worldPosition)) then
                return false, "requested position does not exist in realm " .. tostring(realmID)
            end

            requestedRealm:TeleportPlayer(player)
            player:set_pos(worldPosition)
        elseif (mc_helpers.isNumber(paramTable[1]) and paramTable[2] == nil) then
            return commands["tp"].func(name, paramTable)
        elseif (paramTable[1] ~= nil and paramTable[2] == nil) then
            return teleport(name, paramTable[1])
        elseif (paramTable[1] ~= nil and mc_helpers.isNumber(paramTable[2])) then
            return commands["tp"].func(paramTable[1], { paramTable[2] })
        elseif (paramTable[1] ~= nil and paramTable[2] ~= nil) then
            return teleport(paramTable[1], paramTable[2])
        end

        return false, "unable to parse parameters: " .. tostring(param)
    end,
})