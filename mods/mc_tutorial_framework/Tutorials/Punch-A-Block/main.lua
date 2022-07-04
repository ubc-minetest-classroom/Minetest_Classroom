dofile(mc_tutorialFramework.path .. "/Tutorials/Punch-A-Block/blocks.lua")

punchABlock = { hud = mhud.init() }

punchABlock.tutorialStage = {}

function punchABlock.blockDestroyed(pos, oldnode, oldmetadata, player)
    local pmeta = player:get_meta()

    -- Make sure we're in the tutorial before wasting resources
    if (pmeta:get_string("startedPunchABlock") ~= "true") then
        return
    end

    local key = "Break:" .. oldnode.name

    minetest.debug(key)

    local oldValue = pmeta:get_int(key) or 0
    local newValue = oldValue + 1
    pmeta:set_int(key, newValue)

    punchABlock.progress(player)
end

function punchABlock.progress(player)
    local pmeta = player:get_meta()

    local levels = {}
    levels[0] = { key = "Break:mc_tf:handBreakable", goal = 4,
                  welcomeText = "Welcome! Use your hand to break the purple blocks!",
                  helpText = "Hand Breakable Blocks",
                  reward = ItemStack("default:shovel_steel") }

    levels[1] = { key = "Break:mc_tf:shovelBreakable", goal = 4,
                  welcomeText = "Level up! Use the new shovel that has been deposited into your inventory to break the pink blocks!",
                  helpText = "Shovel Breakable Blocks",
                  reward = ItemStack("default:pick_steel") }

    levels[2] = { key = "Break:mc_tf:pickBreakable", goal = 4,
                  helpText = "Pickaxe Breakable Blocks",
                  welcomeText = "Level up! Use your new pickaxe to break the dark green blocks!",
                  reward = ItemStack("default:axe_steel") }

    levels[3] = { key = "Break:mc_tf:axeBreakable", goal = 4,
                  helpText = "Axe Breakable Blocks",
                  welcomeText = "Level Up! You're now a lumberjack! Go cut some wood (purple blocks)",
                  reward = ItemStack("default:diamond") }

    local level = levels[punchABlock.tutorialStage[player]]
    local key = level.key
    local goal = level.goal
    local value = pmeta:get_int(key)

    if (value > goal) then
        if (level.reward ~= nil) then
            player:get_inventory():add_item("main", level.reward)
        end

        punchABlock.tutorialStage[player] = punchABlock.tutorialStage[player] + 1
        level = levels[punchABlock.tutorialStage[player]]

        if (level == nil) then
            mc_tutorialFramework.infoWindow.show_to(player, "Congratulations! You finished the tutorial")
            minetest.chat_send_player(player:get_player_name(), "Congratulations! You finished the tutorial")
            punchABlock.endTutorial(Realm.realmDict[pmeta:get_int("realm")], player)
        else
            if (level.welcomeText ~= nil) then
                mc_tutorialFramework.infoWindow.show_to(player, level.welcomeText)
                minetest.chat_send_player(player:get_player_name(), level.welcomeText)
            end
        end

    end

    if (level ~= nil) then
        punchABlock.updateHud(player, key, 5, " " .. level.helpText)
    end

end

function punchABlock.startTutorial(realm, player)
    punchABlock.removeHUD(player)
    local pmeta = player:get_meta()

    if (areas) then
        realm:AddPlayerArea(player)
    end

    mc_tutorialFramework.infoWindow.show_to(player, "Welcome to the punch-a-block tutorial." ..
            "This tutorial aims to teach you how to destroy blocks (called nodes)." ..
            "To destroy a node, press and hold the left mouse button while" ..
            "your mouse cursor is above a block. Some nodes are protected or require special tools to destroy." ..
            "You will know if you can destroy a node from the crack-overlay that builds when clicking on the block." ..
            "To get started, find the pile of nodes in-front of you that can be broken by hand. Destroy 5 of these blocks." ..
            "You can track your progress    in your upper right hand of the screen")
    minetest.chat_send_player(player:get_player_name(), "Welcome to the punch-a-block tutorial.")

    punchABlock.CreateHUD(player)

    --Reset all our values
    punchABlock.tutorialStage[player] = 0
    pmeta:set_int("Break:mc_tf:handBreakable", 0)
    pmeta:set_int("Break:mc_tf:shovelBreakable", 0)
    pmeta:set_int("Break:mc_tf:spadeBreakable", 0)
    pmeta:set_int("Break:mc_tf:axeBreakable", 0)

    -- Set that we're in a tutorial
    pmeta:set_string("startedPunchABlock", "true")
end

function punchABlock.endTutorial(realm, player)

    if (areas) then
        realm:RemovePlayerArea(player)
    end

    local pmeta = player:get_meta()

    -- Clear that we're in a tutorial
    pmeta:set_string("startedPunchABlock", false)

    --Clear all our meta values
    punchABlock.tutorialStage[player] = 0
    pmeta:set_int("Break:mc_tf:handBreakable", 0)
    pmeta:set_int("Break:mc_tf:shovelBreakable", 0)
    pmeta:set_int("Break:mc_tf:spadeBreakable", 0)
    pmeta:set_int("Break:mc_tf:axeBreakable", 0)

    punchABlock.removeHUD(player)
    mc_worldManager.GetSpawnRealm():TeleportPlayer(player)
    -- realm:Delete() -- need to figure out how to make the portals re-create the realm when it's destroyed
end

function punchABlock.CreateHUD(player, statKey, Goal, HelpText)

    statKey = statKey or "breakTutorialBlock"
    Goal = Goal or 5
    HelpText = HelpText or " Blocks"

    local meta = player:get_meta()
    local blocksBroken_text = "Broke: " .. meta:get_int(statKey) .. "/" .. Goal .. HelpText

    punchABlock.hud:add(player, "pab:title", {
        hud_elem_type = "text",
        position = { x = 1, y = 0 },
        offset = { x = -16, y = 24 },
        alignment = { x = "left", y = "down" },
        text = "Punch-A-Block Tutorial",
        color = 0x00FF00,
    })

    punchABlock.hud:add(player, "pab:stat", {
        hud_elem_type = "text",
        position = { x = 1, y = 0 },
        offset = { x = -16, y = 42 },
        alignment = { x = "left", y = "down" },
        text = blocksBroken_text,
        color = 0x00FF00,
    })


end

function punchABlock.updateHud(player, statKey, Goal, HelpText)
    statKey = statKey or "breakTutorialBlock"
    Goal = Goal or 5
    HelpText = HelpText or " Blocks"

    local meta = player:get_meta()
    local blocksBroken_text = "Broke: " .. meta:get_int(statKey) .. "/" .. Goal .. HelpText

    punchABlock.hud:change(player, "pab:stat", {
        hud_elem_type = "text",
        position = { x = 1, y = 0 },
        offset = { x = -16, y = 42 },
        alignment = { x = "left", y = "down" },
        text = blocksBroken_text,
        color = 0x00FF00,
    })
end

function punchABlock.removeHUD(player)
    punchABlock.hud:remove(player)
end