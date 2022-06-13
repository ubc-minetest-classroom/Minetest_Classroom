mc_worldManager = { storage = minetest.get_mod_storage(), path = minetest.get_modpath("mc_worldmanager") }

-- Include our source files
dofile(minetest.get_modpath("mc_worldmanager") .. "/realm/realm.lua")
dofile(minetest.get_modpath("mc_worldmanager") .. "/nodes.lua")
dofile(minetest.get_modpath("mc_worldmanager") .. "/commands.lua")
dofile(minetest.get_modpath("mc_worldmanager") .. "/schematicmanager.lua")
dofile(minetest.get_modpath("mc_worldmanager") .. "/hooks.lua")

---@private
---Loads the persistent mod data for mc_worldManager.
---@return void
function mc_worldManager.save_data()
    mc_worldManager.storage:set_string("spawnRealmID", tostring(mc_worldManager.spawnRealmID))
end

---@private
---Saves the persistent mod data for mc_worldManager.
---@return void
function mc_worldManager.load_data()
    mc_worldManager.spawnRealmID = tonumber(mc_worldManager.storage:get_string("spawnRealmID"))
end

mc_worldManager.load_data()

---@public
---Gets the spawn realm of the world.
---It's important to use this function to grab the world spawn to ensure that it always exists.
---Note that although the realm ID for spawn is usually 1, it can change without notice.
---This function ensures that systems that rely on a spawn don't break.
---@return table Realm
function mc_worldManager.GetSpawnRealm()
    local spawnRealm = Realm.realmDict[mc_worldManager.spawnRealmID]
    if (spawnRealm == nil) then
        spawnRealm = Realm:NewFromSchematic("Spawn Realm", "vancouver_osm")

        mc_worldManager.spawnRealmID = spawnRealm.ID
        mc_worldManager.save_data()
    end
    return spawnRealm
end

-- Registration
schematicManager.registerSchematicPath("shack", mc_worldManager.path .. "/schematics/shack")

