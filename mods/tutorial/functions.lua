function tutorial.checkPrivs(player,priv_table)
    local priv_table = priv_table or {interact = true}
    local name = player:get_player_name()
    return minetest.check_player_privs(name, priv_table)
end

function tutorial.wait(seconds)
    local t = os.clock()
    while os.clock() - t < seconds do end
end

function tutorial.register_tutorial_action(player,action,tool,node,pos,dir,key)
    -- Every entry must have an action
    if not action then return false end
    -- Handle other optional arguments (default values)
    local tool = tool or ""
    local node = node or ""
    local pos = pos or {}
    local dir = dir or -1
    local key = key or {}
    if tutorial.checkPrivs(player,tutorial.recorder_priv_table) and tutorial.recordingActive then
        if tutorial.instancedTutorial then
            -- This is the first entry for the tutorial, apply default values
            tutorial.tutorialTemp = {
                tutorialID = 0, -- integer key used to identify thisTutorial
                tutorialDependency = {}, -- table of tutorialIDs that must be compeleted before the player can attempt this tutorial
                tutorialSequence = {
                    action = {}, -- string
                    tool = {}, -- string
                    node = {}, -- string
                    pos = {}, -- table
                    dir = {}, -- integer
                    key = {}, -- table
                    actionMessage = {} -- table of strings displayed to player when an action is completed
                },
                length = 0,
                on_completion = {
                    message = "",
                    givetool = {},
                    giveitem = {},
                    grantpriv = {}
                }
            }
            tutorial.instancedTutorial = false
        end
        -- Populate the tutorialSequence
        table.insert(tutorial.tutorialTemp.tutorialSequence.action, action)
        table.insert(tutorial.tutorialTemp.tutorialSequence.tool, tool)
        table.insert(tutorial.tutorialTemp.tutorialSequence.node, node)
        table.insert(tutorial.tutorialTemp.tutorialSequence.pos, pos)
        table.insert(tutorial.tutorialTemp.tutorialSequence.dir, dir)
        table.insert(tutorial.tutorialTemp.tutorialSequence.key, key)
        tutorial.tutorialTemp.length = tutorial.tutorialTemp.length + 1
    end
end

-- If needed, this function runs continuously after starting a tutorial.
-- It listens for specific actions in the tutorialSequence that do not have callbacks (punch, dig, place).
-- If the action is heard, then it checks against th    e expected value.
-- if the action matches the expected value, then the listener registers the completed action.
-- Once activeTutorial.continueTutorial = false (i.e., the tutorial is completed), the listener turns off.
function tutorial.tutorial_progress_listener(player)
    pmeta = player:get_meta()
    pdata = minetest.deserialize(pmeta:get_string("tutorials"))
    
    if pdata.tutorials.activeTutorial and pdata.tutorials.activeTutorial.continueTutorial and not tutorial.recordingActive then
        -- Figure out the type of action to call the correct listener
        if pdata.tutorials.activeTutorial.tutorialSequence.action[pdata.tutorials.activeTutorial.searchIndex] == "current position" then
            pdata.tutorials.playerSequence.pos = player:get_pos()
            check_pos = pdata.tutorials.activeTutorial.tutorialSequence.pos[pdata.tutorials.activeTutorial.searchIndex]
            -- minetest.get_objects_inside_radius(pos, radius) may be better here?
            if (pdata.tutorials.playerSequence.pos.x >= check_pos.x - tutorial.check_pos_x_tolerance) and (pdata.tutorials.playerSequence.pos.x <= check_pos.x + tutorial.check_pos_x_tolerance) and (pdata.tutorials.playerSequence.pos.y >= check_pos.y - tutorial.check_pos_y_tolerance) and (pdata.tutorials.playerSequence.pos.y <= check_pos.y + tutorial.check_pos_y_tolerance) and (pdata.tutorials.playerSequence.pos.z >= check_pos.z - tutorial.check_pos_z_tolerance) and (pdata.tutorials.playerSequence.pos.z <= check_pos.z + tutorial.check_pos_z_tolerance) then
                tutorial.completed_action(player)
            end
        elseif pdata.tutorials.activeTutorial.tutorialSequence.action[pdata.tutorials.activeTutorial.searchIndex] == "look direction" then
            -- TODO
            minetest.chat_send_player(pdata.tutorials.activeTutorial.pname,"[Tutorial] listening for look direction...")
        elseif pdata.tutorials.activeTutorial.tutorialSequence.action[pdata.tutorials.activeTutorial.searchIndex] == "look pitch" then
            pdata.tutorials.playerSequence.dir = player:get_look_vertical()
            check_dir = pdata.tutorials.activeTutorial.tutorialSequence.dir[pdata.tutorials.activeTutorial.searchIndex]
            if (pdata.tutorials.playerSequence.dir >= check_dir - tutorial.check_dir_tolerance) and (pdata.tutorials.playerSequence.dir <= check_dir + tutorial.check_dir_tolerance) then
                tutorial.completed_action(player)
            end
        elseif pdata.tutorials.activeTutorial.tutorialSequence.action[pdata.tutorials.activeTutorial.searchIndex] == "look yaw" then
            pdata.tutorials.playerSequence.dir = player:get_look_horizontal()
            check_dir = pdata.tutorials.activeTutorial.tutorialSequence.dir[pdata.tutorials.activeTutorial.searchIndex]
            if (pdata.tutorials.playerSequence.dir >= check_dir - tutorial.check_dir_tolerance) and (pdata.tutorials.playerSequence.dir <= check_dir + tutorial.check_dir_tolerance) then
                tutorial.completed_action(player)
            end
        elseif pdata.tutorials.activeTutorial.tutorialSequence.action[pdata.tutorials.activeTutorial.searchIndex] == "wield" then
            pdata.tutorials.playerSequence.wieldedThing = player:get_wielded_item():get_name()
            if pdata.tutorials.playerSequence.wieldedThing == "" then pdata.tutorials.playerSequence.wieldedThing = "bare hands" end
            if pdata.tutorials.playerSequence.wieldedThing == pdata.tutorials.activeTutorial.tutorialSequence.node[pdata.tutorials.activeTutorial.searchIndex] then
                tutorial.completed_action(player)
            end
        elseif pdata.tutorials.activeTutorial.tutorialSequence.action[pdata.tutorials.activeTutorial.searchIndex] == "player control" then
            minetest.chat_send_player(pdata.tutorials.activeTutorial.pname,"[Tutorial] listening for key strike...")
            pdata.tutorials.playerSequence.keyStrike = player:get_player_control()
            if pdata.tutorials.playerSequence.keyStrike.up or pdata.tutorials.playerSequence.keyStrike.down or pdata.tutorials.playerSequence.keyStrike.right or pdata.tutorials.playerSequence.keyStrike.left or pdata.tutorials.playerSequence.keyStrike.aux1 or pdata.tutorials.playerSequence.keyStrike.jump or pdata.tutorials.playerSequence.keyStrike.sneak then
                pdata.tutorials.playerSequence.keys = {}
                for k,v in pairs(pdata.tutorials.playerSequence.keyStrike) do if v then table.insert(pdata.tutorials.playerSequence.keys,k) end end
                if table.concat(pdata.tutorials.playerSequence.keys) == table.concat(pdata.tutorials.activeTutorial.tutorialSequence.key[pdata.tutorials.activeTutorial.searchIndex]) then
                    tutorial.completed_action(player)
                end
            end
        end
        minetest.after(tutorial.check_interval, tutorial.tutorial_progress_listener(player))
    end
end

-- This function is used to update the search index on completion of an action and check if the tutorial is completed.
-- If tutorial is completed, then initiate the on_complettion callbacks: give tool, give item, grant priv.
function tutorial.completed_action(player)
    local pname = player:get_player_name()
    pmeta = player:get_meta()
    pdata = minetest.deserialize(pmeta:get_string("tutorials"))
    
    -- Action was successfully completed, so update the searchIndex and completed
    if pdata.tutorials.activeTutorial.searchIndex <= pdata.tutorials.activeTutorial.length then 
        pdata.tutorials.activeTutorial.searchIndex = pdata.tutorials.activeTutorial.searchIndex + 1 
    end
    pdata.tutorials.activeTutorial.completed = pdata.tutorials.activeTutorial.completed + 1
    minetest.sound_play("bell", {gain = 1.0, pitch = 1.0, to_player = pname}, true)
    -- Check if tutorial is completed
    if pdata.tutorials.activeTutorial.completed >= pdata.tutorials.activeTutorial.length then
        -- on_completion callbacks here
        minetest.chat_send_player(pname,"[Tutorial] "..pdata.tutorials.activeTutorial.on_completion.message)
        pdata.tutorials.activeTutorial.continueTutorial = false
        pdata.tutorials.wieldedThingListener = false
        pmeta:set_string("tutorials", minetest.serialize(pdata))
        local inv = player:get_inventory()
        -- Check if the player already has the tool
        if pdata.tutorials.activeTutorial.on_completion.givetool then
            if inv:contains_item("main", ItemStack(pdata.tutorials.activeTutorial.on_completion.givetool)) then
                return
            else
                inv:add_item("main", pdata.tutorials.activeTutorial.on_completion.givetool)
            end
        end
        if pdata.tutorials.activeTutorial.on_completion.giveitem then
            -- Check if the player already has the item
            if inv:contains_item("main", ItemStack(pdata.tutorials.activeTutorial.on_completion.giveitem)) then
                return
            else
                inv:add_item("main", pdata.tutorials.activeTutorial.on_completion.giveitem)
            end
        end
        if pdata.tutorials.activeTutorial.on_completion.grantpriv then
            -- TODO
        end
    end
end

-- This function is used specifically with defined callbacks (punch, dig, place) and therefore only checks for action, tool, and node
function tutorial.check_tutorial_progress(player,action,tool,node)
    local pname = player:get_player_name()
    pmeta = player:get_meta()
    pdata = minetest.deserialize(pmeta:get_string("tutorials"))
    -- TODO: retrieve pdata.tutorials.activeTutorial from player meta
    -- any player can complete a tutorial, but don't attempt a tutorial if one is being recorded
    if pdata.tutorials.activeTutorial and pdata.tutorials.activeTutorial.continueTutorial and not tutorial.recordingActive then
        if action then
            pdata.tutorials.playerSequence.action = action
            pdata.tutorials.playerSequence.tool = tool or ""
            pdata.tutorials.playerSequence.node = node or ""
        else return false end

        -- match the action first since this callback might not even be relevant
        if pdata.tutorials.playerSequence.action == pdata.tutorials.activeTutorial.tutorialSequence.action[pdata.tutorials.activeTutorial.searchIndex] then
            -- match the node next
            if pdata.tutorials.playerSequence.node == pdata.tutorials.activeTutorial.tutorialSequence.node[pdata.tutorials.activeTutorial.searchIndex] then
                -- finally match the tool
                if pdata.tutorials.playerSequence.tool == pdata.tutorials.activeTutorial.tutorialSequence.tool[pdata.tutorials.activeTutorial.searchIndex] then
                    tutorial.completed_action(player)
                end
            end
        end
    else 
        return 
    end
end