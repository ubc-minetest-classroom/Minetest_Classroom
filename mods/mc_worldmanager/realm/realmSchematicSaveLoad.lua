---@public
---Save_Schematic
---@return string, boolean The filepath of the schematic; whether the settings file wrote succesfully.
---@public
---Save_Schematic
---@return string, boolean The filepath of the schematic; whether the settings file wrote succesfully.
function Realm:Save_Schematic(author, mode)
    author = author or "unknown"
    mode = mode or "old"

    local folderpath = minetest.get_worldpath() .. "/schematics/"

    minetest.mkdir(folderpath)

    local fileName = "Realm " .. self.ID .. " " .. math.random(0, 9999) .. os.date(" %Y%m%d %H%M%S")
    local filepath = folderpath .. "/" .. fileName

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

    fileName = fileName .. os.date(" %Y%m%d %H%M")

    local filepath = folderpath .. "\\" .. fileName
    
    --minetest.create_schematic(self.StartPos, self.EndPos, nil, filepath .. ".mts", nil)

    local file, err = io.open(filepath .. ".mts", "wb")
    if err then return 0 end
    local schematic, count = worldedit.serialize(self.StartPos, self.EndPos)
    file:write(schematic)
    file:close()

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

    local settingsWrote = settings:write()

    return filepath, settingsWrote
end

---@public
---Load_Schematic
---@param key string the corresponding value for this schematic as registered by the schematic manager.
---@return boolean whether the schematic fit entirely in the realm when loading.
function Realm:Load_Schematic(schematic, config)

    --TODO: Add code to check if the realm is large enough to support the schematic; If not, create a new realm that can;
    local schematicEndPos = self:LocalToWorldPosition(config.schematicSize)
    self.EndPos = schematicEndPos


    --exschem is having issues loading random chunks, need to debug
    if (config.format == "exschem") then
        exschem.load(self.StartPos, self.StartPos, 0, {}, schematic, 0,
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
        worldedit.deserialize(self.StartPos, decompressed)
    elseif (config.format == "procedural") then
        -- do nothing if we're a procedural map; it will be taking care of by the onSchematicPlaceFunction
    else
        -- Read data into LVM
        local vm = minetest.get_voxel_manip()
        local emin, emax = vm:read_from_map(self.StartPos, self.EndPos)
        local a = VoxelArea:new {
            MinEdge = emin,
            MaxEdge = emax
        }

        minetest.place_schematic_on_vmanip(vm, self.StartPos, schematic .. ".mts", 0, nil, true)
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

    local newRealm = Realm:New(name, config.schematicSize)
    newRealm:Load_Schematic(schematic, config)

    if (config.format ~= "procedural") then
        --TODO: temporarily disabled for UBC because it doesn't work with super large worlds;
        -- Need to emerge chunks as we create barriers
        newRealm:CreateBarriers()
    end

    return newRealm
end