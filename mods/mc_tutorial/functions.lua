function mc_tutorial.check_privs(player, priv_table)
    local priv_table = priv_table or {interact = true}
    local name = player:get_player_name()
    return minetest.check_player_privs(name, priv_table)
end

function mc_tutorial.wait(seconds)
    local t = os.clock()
    while os.clock() - t < seconds do end
end

function mc_tutorial.get_temp_shell()
    return {
        dependencies = {}, -- table of tutorial IDs that must be compeleted before the player can attempt this tutorial
        dependents = {}, -- table of tutorial IDs that completing this tutorial unlocks
        sequence = {},
        length = 0,
        on_completion = {
            message = "",
            give_items = {},
            grant_privs = {}
        }
    }
end

function mc_tutorial.register_tutorial_action(player, action, tool, node, pos, dir, key)
    -- Every entry must have an action
    if not action then
        return false
    end
    local pname = player:get_player_name()

    if mc_tutorial.check_privs(player,mc_tutorial.recorder_priv_table) and mc_tutorial.record.active[pname] then
        if not mc_tutorial.record.temp[pname] then
            -- This is the first entry for the tutorial, apply default values
            mc_tutorial.record.temp[pname] = mc_tutorial.get_temp_shell()
        end
        -- Populate the sequence
        table.insert(mc_tutorial.record.temp[pname].sequence, {
            action = action,
            tool = tool or nil,
            node = node or nil,
            pos = pos or nil,
            dir = dir or nil,
            key = key or nil
        })
        mc_tutorial.record.temp[pname].length = mc_tutorial.record.temp[pname].length + 1
    end
end

-- If needed, this function runs continuously after starting a mc_tutorial.
-- It listens for specific actions in the sequence that do not have callbacks (punch, dig, place).
-- If the action is heard, then it checks against the expected value.
-- if the action matches the expected value, then the listener registers the completed action.
-- Once activeTutorial.continueTutorial = false (i.e., the tutorial is completed), the listener turns off.
function mc_tutorial.tutorial_progress_listener(player)
    local pmeta = player:get_meta()
    local pdata = minetest.deserialize(pmeta:get_string("mc_tutorial"))
    local pname = player:get_player_name()
    
    if pdata.tutorials.activeTutorial and pdata.tutorials.activeTutorial.continueTutorial and not mc_tutorial.record.active[pname] then
        -- Figure out the type of action to call the correct listener
        if pdata.tutorials.activeTutorial.sequence.action[pdata.tutorials.activeTutorial.searchIndex] == mc_tutorial.ACTION.POS then
            pdata.tutorials.playerSequence.pos = player:get_pos()
            check_pos = pdata.tutorials.activeTutorial.sequence.pos[pdata.tutorials.activeTutorial.searchIndex]
            -- minetest.get_objects_inside_radius(pos, radius) may be better here?
            -- minetest.get_objects_in_area(pos1, pos2) would also work
            if (pdata.tutorials.playerSequence.pos.x >= check_pos.x - mc_tutorial.check_pos_x_tolerance) and (pdata.tutorials.playerSequence.pos.x <= check_pos.x + mc_tutorial.check_pos_x_tolerance) and (pdata.tutorials.playerSequence.pos.y >= check_pos.y - mc_tutorial.check_pos_y_tolerance) and (pdata.tutorials.playerSequence.pos.y <= check_pos.y + mc_tutorial.check_pos_y_tolerance) and (pdata.tutorials.playerSequence.pos.z >= check_pos.z - mc_tutorial.check_pos_z_tolerance) and (pdata.tutorials.playerSequence.pos.z <= check_pos.z + mc_tutorial.check_pos_z_tolerance) then
                mc_tutorial.completed_action(player)
            end
        elseif pdata.tutorials.activeTutorial.sequence.action[pdata.tutorials.activeTutorial.searchIndex] == mc_tutorial.ACTION.LOOK_DIR then
            -- TODO
            minetest.chat_send_player(pdata.tutorials.activeTutorial.pname,"[Tutorial] listening for look direction...")
        elseif pdata.tutorials.activeTutorial.sequence.action[pdata.tutorials.activeTutorial.searchIndex] == mc_tutorial.ACTION.LOOK_PITCH then
            pdata.tutorials.playerSequence.dir = player:get_look_vertical()
            check_dir = pdata.tutorials.activeTutorial.sequence.dir[pdata.tutorials.activeTutorial.searchIndex]
            if (pdata.tutorials.playerSequence.dir >= check_dir - mc_tutorial.check_dir_tolerance) and (pdata.tutorials.playerSequence.dir <= check_dir + mc_tutorial.check_dir_tolerance) then
                mc_tutorial.completed_action(player)
            end
        elseif pdata.tutorials.activeTutorial.sequence.action[pdata.tutorials.activeTutorial.searchIndex] == mc_tutorial.ACTION.LOOK_YAW then
            pdata.tutorials.playerSequence.dir = player:get_look_horizontal()
            check_dir = pdata.tutorials.activeTutorial.sequence.dir[pdata.tutorials.activeTutorial.searchIndex]
            if (pdata.tutorials.playerSequence.dir >= check_dir - mc_tutorial.check_dir_tolerance) and (pdata.tutorials.playerSequence.dir <= check_dir + mc_tutorial.check_dir_tolerance) then
                mc_tutorial.completed_action(player)
            end
        elseif pdata.tutorials.activeTutorial.sequence.action[pdata.tutorials.activeTutorial.searchIndex] == mc_tutorial.ACTION.WIELD then
            pdata.tutorials.playerSequence.wieldedThing = player:get_wielded_item():get_name()
            --if pdata.tutorials.playerSequence.wieldedThing == "" then pdata.tutorials.playerSequence.wieldedThing = "bare hands" end
            if pdata.tutorials.playerSequence.wieldedThing == pdata.tutorials.activeTutorial.sequence.node[pdata.tutorials.activeTutorial.searchIndex] then
                mc_tutorial.completed_action(player)
            end
        elseif pdata.tutorials.activeTutorial.sequence.action[pdata.tutorials.activeTutorial.searchIndex] == mc_tutorial.ACTION.KEY then
            minetest.chat_send_player(pdata.tutorials.activeTutorial.pname,"[Tutorial] listening for key strike...")
            pdata.tutorials.playerSequence.keyStrike = player:get_player_control()
            if pdata.tutorials.playerSequence.keyStrike.up or pdata.tutorials.playerSequence.keyStrike.down or pdata.tutorials.playerSequence.keyStrike.right or pdata.tutorials.playerSequence.keyStrike.left or pdata.tutorials.playerSequence.keyStrike.aux1 or pdata.tutorials.playerSequence.keyStrike.jump or pdata.tutorials.playerSequence.keyStrike.sneak then
                pdata.tutorials.playerSequence.keys = {}
                for k,v in pairs(pdata.tutorials.playerSequence.keyStrike) do if v then table.insert(pdata.tutorials.playerSequence.keys,k) end end
                if table.concat(pdata.tutorials.playerSequence.keys) == table.concat(pdata.tutorials.activeTutorial.sequence.key[pdata.tutorials.activeTutorial.searchIndex]) then
                    mc_tutorial.completed_action(player)
                end
            end
        end
        minetest.after(mc_tutorial.check_interval, mc_tutorial.tutorial_progress_listener(player))
    end
end

-- This function is used to update the search index on completion of an action and check if the tutorial is completed.
-- If tutorial is completed, then initiate the on_complettion callbacks: give tool, give item, grant priv.
function mc_tutorial.completed_action(player)
    local pname = player:get_player_name()
    local pmeta = player:get_meta()
    local pdata = minetest.deserialize(pmeta:get_string("mc_tutorial"))
    
    -- Action was successfully completed, so update the searchIndex and completed
    if pdata.tutorials.activeTutorial.searchIndex <= pdata.tutorials.activeTutorial.length then 
        pdata.tutorials.activeTutorial.searchIndex = pdata.tutorials.activeTutorial.searchIndex + 1 
    end
    pdata.tutorials.activeTutorial.completed = pdata.tutorials.activeTutorial.completed + 1
    minetest.sound_play("bell", {gain = 1.0, pitch = 1.0, to_player = pname}, true)
    -- Check if tutorial is completed
    if pdata.tutorials.activeTutorial.completed >= pdata.tutorials.activeTutorial.length then
        -- on_completion callbacks here
        minetest.chat_send_player(pname, "[Tutorial] "..pdata.tutorials.activeTutorial.on_completion.message)
        pdata.tutorials.activeTutorial.continueTutorial = false
        pdata.tutorials.wieldThingListener = false
        pmeta:set_string("mc_tutorial", minetest.serialize(pdata))

        local inv = player:get_inventory()
        -- Check if the player already has the tool
        if pdata.tutorials.activeTutorial.on_completion.givetool then
            if not mc_helpers.getInventoryItemLocation(inv, pItemStack(pdata.tutorials.activeTutorial.on_completion.givetool)) then
                inv:add_item("main", pdata.tutorials.activeTutorial.on_completion.givetool)
            end
        end
        if pdata.tutorials.activeTutorial.on_completion.giveitem then
            -- Check if the player already has the item
            if not mc_helpers.getInventoryItemLocation(inv, ItemStack(pdata.tutorials.activeTutorial.on_completion.giveitem)) then
                inv:add_item("main", pdata.tutorials.activeTutorial.on_completion.giveitem)
            end
        end
        if pdata.tutorials.activeTutorial.on_completion.grantpriv then
            -- TODO
        end
    end
end

-- This function is used specifically with defined callbacks (punch, dig, place) and therefore only checks for action, tool, and node
function mc_tutorial.check_tutorial_progress(player,action,tool,node)
    local pname = player:get_player_name()
    local pmeta = player:get_meta()
    local pdata = minetest.deserialize(pmeta:get_string("mc_tutorial"))
    -- TODO: retrieve pdata.tutorials.activeTutorial from player meta
    -- any player can complete a tutorial, but don't attempt a tutorial if one is being recorded
    if pdata.tutorials.activeTutorial and pdata.tutorials.activeTutorial.continueTutorial and not mc_tutorial.record.active[pname] then
        if action then
            pdata.tutorials.playerSequence.action = action
            pdata.tutorials.playerSequence.tool = tool or false
            pdata.tutorials.playerSequence.node = node or false
        else return false end

        -- match the action first since this callback might not even be relevant
        if pdata.tutorials.playerSequence.action == pdata.tutorials.activeTutorial.sequence.action[pdata.tutorials.activeTutorial.searchIndex] then
            -- match the node next
            if pdata.tutorials.playerSequence.node == pdata.tutorials.activeTutorial.sequence.node[pdata.tutorials.activeTutorial.searchIndex] then
                -- finally match the tool
                if pdata.tutorials.playerSequence.tool == pdata.tutorials.activeTutorial.sequence.tool[pdata.tutorials.activeTutorial.searchIndex] then
                    mc_tutorial.completed_action(player)
                end
            end
        end
    else 
        return 
    end
end