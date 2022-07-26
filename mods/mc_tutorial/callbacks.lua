-- Register the punch, dig, and place callbacks
minetest.register_on_punchnode(function(pos, node, player, pointed_thing)
    local pname = player:get_player_name()
    if mc_tutorial.record.active[pname] or mc_tutorial.active[pname] then
        local action = mc_tutorial.ACTION.PUNCH
        local tool = player:get_wielded_item():get_name()
        local node = node.name

        if mc_tutorial.record.active[pname] then
            mc_tutorial.register_tutorial_action(player, action, tool, node)
        elseif mc_tutorial.active[pname] then
            mc_tutorial.check_tutorial_progress(player, action, tool, node)
        end
    end
end)

minetest.register_on_dignode(function(pos, oldnode, player)
    local pname = player:get_player_name()
    if mc_tutorial.record.active[pname] or mc_tutorial.active[pname] then
        local action = mc_tutorial.ACTION.DIG
        local tool = player:get_wielded_item():get_name()
        local node = oldnode.name
        if mc_tutorial.record.active[pname] then
            mc_tutorial.register_tutorial_action(player, action, tool, node)
        elseif mc_tutorial.active[pname] then
            mc_tutorial.check_tutorial_progress(player, action, tool, node)
        end
    end
end)

minetest.register_on_placenode(function(pos, newnode, player, oldnode, itemstack, pointed_thing)
    local pname = player:get_player_name()
    if mc_tutorial.record.active[pname] or mc_tutorial.active[pname] then
        local action = mc_tutorial.ACTION.PLACE
        local tool = player:get_wielded_item():get_name()
        local node = newnode.name
        if mc_tutorial.record.active[pname] then
            mc_tutorial.register_tutorial_action(player, action, tool, node)
        elseif mc_tutorial.active[pname] then
            mc_tutorial.check_tutorial_progress(player, action, tool, node)
        end
    end
end)

-- Listener for wield and player control (key strike)
minetest.register_globalstep(function(dtime)
    if mc_tutorial and next(mc_tutorial.record.active) and (next(mc_tutorial.record.listener.wield) or next(mc_tutorial.record.listener.key)) then
        for pname,_ in pairs(mc_tutorial.record.active) do
            local reset_timer = false
            local timer = (mc_tutorial.record.timer[pname] or 0) + dtime
            local player = minetest.get_player_by_name(pname)

            -- Listen for wield_item
            if timer > 5 and mc_tutorial.record.listener.wield[pname] then
                reset_timer = true
                local wield = player:get_wielded_item():get_name()

                if wield ~= "mc_tutorial:recording_tool" then
                    minetest.chat_send_player(pname, "[Tutorial] Wielded item "..wield.." recorded.")
                    mc_tutorial.register_tutorial_action(player, mc_tutorial.ACTION.WIELD, wield)
                    mc_tutorial.record.listener.wield[pname] = nil
                end
            end

            -- Listen for keystroke, if triggered
            if timer > 1 and mc_tutorial.record.listener.key[pname] == "track" then
                reset_timer = true
                local keyStrike = player:get_player_control()
    
                if keyStrike.up or keyStrike.down or keyStrike.right or keyStrike.left or keyStrike.aux1 or keyStrike.jump or keyStrike.sneak then
                    local keys = {}
                    for k,v in pairs(keyStrike) do
                        if v then table.insert(keys, k) end
                    end
                    local msg = "[Tutorial] Keystroke "..table.concat(keys, " + ").." recorded."
                    minetest.chat_send_player(pname, msg)
                    mc_tutorial.register_tutorial_action(player, mc_tutorial.ACTION.KEY, nil, nil, nil, nil, keys)
                    mc_tutorial.record.listener.key[pname] = nil
                end
            end

            -- Start keystroke timer
            if mc_tutorial.record.listener.key[pname] == true and player:get_player_control_bits() ~= 0 then
                minetest.chat_send_player(pname, "[Tutorial] Recording keystroke, please continue to hold the player control keys you would like to record.")
                mc_tutorial.record.listener.key[pname] = "track"
                reset_timer = true
            end

            mc_tutorial.record.timer[pname] = (reset_timer and 0) or timer
        end
    end
end)
