---@public
---Save_Schematic
---@return string, boolean The filepath of the schematic; whether the settings file wrote succesfully.
---@public
---Save_Schematic
---@return string, boolean The filepath of the schematic; whether the settings file wrote succesfully.
function Realm:Save_Schematic(schematicName, author, mode)

    if (schematicName == nil or schematicName == "nil" or schematicName == "") then
        schematicName = self.Name
    end

    author = author or "unknown"
    mode = mode or "old"

    local folderpath = minetest.get_worldpath() .. "\\realmSchematics\\"

    minetest.mkdir(folderpath)

    local fileName = schematicName
    local filepath = folderpath .. fileName

    if (mode == "exschem") then
        exschem.save(self.StartPos, self.EndPos, false, 40, filepath, 0,
                function(id, errcode, error)
                    Debug.log("Finished saving")
                    if (error ~= nil) then
                        Debug.log(error)
                    end
                end)
    elseif (mode == "exschemwe") then
        mode = "exschem"
        self:CleanNodes()
        exschem.save(self.StartPos, self.EndPos, true, 40, filepath, 0,
                function(id, errcode, error)
                    Debug.log("Finished saving")
                    if (error ~= nil) then
                        Debug.log(error)
                    end
                end)
    elseif (mode == "worldedit") then
        local data, count = worldedit.serialize(self.StartPos, self.EndPos)
        local compressed = mc_helpers.compress(data)
        local file, err = io.open(filepath .. ".wes", 'wb')
        if file then
            file:write(data)
            file:flush()
            file:close()
        else
            Debug.log("Unable to save realm; save file wouldn't open...")
        end
    else
        self:CleanNodes()
        minetest.create_schematic(self.StartPos, self.EndPos, nil, filepath .. ".mts", nil)
    end

    local settings = Settings(filepath .. ".conf")
    settings:set("author", author)
    settings:set("name", self.Name)
    settings:set("format", mode)

    settings:set("spawn_pos_x", self.SpawnPoint.x - self.StartPos.x)
    settings:set("spawn_pos_y", self.SpawnPoint.y - self.StartPos.y)
    settings:set("spawn_pos_z", self.SpawnPoint.z - self.StartPos.z)

    settings:set("schematic_size_x", self.EndPos.x - self.StartPos.x)
    settings:set("schematic_size_y", self.EndPos.y - self.StartPos.y)
    settings:set("schematic_size_z", self.EndPos.z - self.StartPos.z)


    local utmInfo = self:get_data("UTMInfo")

    if (utmInfo ~= nil) then
        settings:set("utm_zone", utmInfo.zone)
        settings:set("utm_easting", utmInfo.easting)
        settings:set("utm_northing", utmInfo.northing)
    end


    local settingsWrote = settings:write()

    if (settingsWrote == false) then
        Debug.log("Unable to save realm; Settings did not write correctly...")
    end

    schematicManager.registerSchematicPath(schematicName, filepath)

    return filepath, settingsWrote
end

---@public
---Load_Schematic
---@param key string the corresponding value for this schematic as registered by the schematic manager.
---@return boolean whether the schematic fit entirely in the realm when loading.
function Realm:Load_Schematic(schematic, config)


    local schematicStartPos = self:LocalToWorldPosition(config.startOffset)

    --TODO: Add code to check if the realm is large enough to support the schematic; If not, create a new realm that can;
    local schematicEndPos = self:LocalToWorldSpace(config.schematicSize)


    local schematicEndPos = self:LocalToWorldPosition(config.schematicSize)
    if (schematicEndPos.x > self.EndPos.x or schematicEndPos.y > self.EndPos.y or schematicEndPos.z > self.EndPos.z) then

        Debug.log("Schematic is too large for realm, creating a new realm with the same name but larger size")

        local realm = Realm:New(self.Name, schematicEndPos, true)
        self:Delete()
        self = realm
    else
        if (schematicEndPos.x == nil or schematicEndPos == 0) then
            schematicEndPos.x = 80
            Debug.log("Schematic size x is 0, setting to 80")
        end

        if (schematicEndPos.y == nil or schematicEndPos == 0) then
            schematicEndPos.y = 80
            Debug.log("Schematic size y is 0, setting to 80")
        end

        if (schematicEndPos.z == nil or schematicEndPos == 0) then
            schematicEndPos.z = 80
            Debug.log("Schematic size z is 0, setting to 80")
        end

        self.EndPos = schematicEndPos
    end

    if (config.utmInfo ~= nil) then
        self:set_data("UTMInfo", config.utmInfo)
    end





    --exschem is having issues loading random chunks, need to debug
    if (config.format == "exschem") then
        exschem.load(schematicStartPos, schematicStartPos, 0, {}, schematic, 0,
                function(id, time, errcode, err)
                    Debug.log("Loading " .. id .. time)

                    if (errcode ~= nil) then
                        Debug.log(errcode)
                    end

                    if (err ~= nil) then
                        Debug.log(errcode)
                    end

                end)


    elseif (config.format == "worldedit") then
        local file, err = io.open(schematic .. ".wes", 'rb')
        local data = ""
        if file then
            data = file:read("*a")
            file:close()
        else
            Debug.log("Unable to save realm; save file wouldn't open...")
        end

        local decompressed = mc_helpers.decompress(data)
        worldedit.deserialize(schematicStartPos, decompressed)
    elseif (config.format == "procedural") then
        -- do nothing if we're a procedural map; it will be taking care of by the onSchematicPlaceFunction
    else
        -- Read data into LVM
        local vm = minetest.get_voxel_manip()
        local emin, emax = vm:read_from_map(schematicStartPos, self.EndPos)
        local a = VoxelArea:new {
            MinEdge = emin,
            MaxEdge = emax
        }

        minetest.place_schematic_on_vmanip(vm, schematicStartPos, schematic .. ".mts", 0, nil, true)
        vm:write_to_map(true)
    end

    if (config.tableName ~= nil) then
        if (config.onSchematicPlaceFunction ~= nil) then
            local table = loadstring("return " .. config.tableName)()
            table[config.onSchematicPlaceFunction](self)
        end

        if (config.onTeleportInFunction ~= nil) then
            table.insert(self.PlayerJoinTable, { tableName = config.tableName, functionName = config.onTeleportInFunction })
        end

        if (config.onTeleportOutFunction ~= nil) then
            table.insert(self.PlayerLeaveTable, { tableName = config.tableName, functionName = config.onTeleportOutFunction })
        end

        if (config.onRealmDeleteFunction ~= nil) then
            table.insert(self.RealmDeleteTable, { tableName = config.tableName, functionName = config.onRealmDeleteFunction })
        end

    end

    self:UpdateSpawn(config.spawnPoint)
end

function Realm:NewFromSchematic(name, key)
    local schematic, config = schematicManager.getSchematic(key)

    if (name == "" or name == nil) then
        name = config.name
    end

    local newRealm = Realm:New(name, config.schematicSize, false)
    newRealm:Load_Schematic(schematic, config)

    if (config.format ~= "procedural") then
        --TODO: temporarily disabled for UBC because it doesn't work with super large worlds;
        -- Need to emerge chunks as we create barriers
        newRealm:CreateBarriersFast()
    end

    -- Realm:CreateTeleporter()


    newRealm:CallOnCreateCallbacks()

    return newRealm
end