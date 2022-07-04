---@public
---RemovePlayerArea
---Grants permission to a player to break blocks in a realm.
---Requires the areas mod to be installed to be registered into the Realm table
---Check that `areas` is defined before calling.
---@param player table
function Realm:AddPlayerArea(player)
    local playerName = player:get_player_name()
    local realmArea = self:get_string("protectionID")

    if (self.MetaStorage.areas == nil) then
        self.MetaStorage.areas = {}
    end
    local playerArea = self.MetaStorage.areas[playerName]

    if (playerArea == nil) then
        Debug.log(realmArea)
        self.MetaStorage.areas[player:get_player_name()] = areas:add(playerName, playerName .. " Zone in " .. self.Name, self.StartPos, self.EndPos, realmArea)
        areas:save()
    end
end

---@public
---RemovePlayerArea
---Removes permission from a player to break blocks in a realm.
---Requires the areas mod to be installed to be registered into the Realm table
-----Check that `areas` is defined before calling.
---@param player table
function Realm:RemovePlayerArea(player)
    local playerName = player:get_player_name()

    if (self.MetaStorage.areas == nil) then
        self.MetaStorage.areas = {}
    end
    local playerArea = self.MetaStorage.areas[playerName]
    if (playerArea ~= nil) then
        areas:remove(playerArea, true)
        areas:save()
        self.MetaStorage.areas[playerName] = nil
    end
end