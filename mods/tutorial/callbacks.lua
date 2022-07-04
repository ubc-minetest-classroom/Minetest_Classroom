-- Register the punch, dig, and place callbacks
minetest.register_on_punchnode(function(pos, node, puncher, pointed_thing) 
    local pname = puncher:get_player_name()
    local action = "punch"
    -- Detect if player is wielding a tool for punch
    local tool = puncher:get_wielded_item():get_name()
    local node = node.name
    local pos = {}
    local dir = -1
    local key = {}
    tutorial.register_tutorial_action(puncher,action,tool,node,pos,dir,key)
    tutorial.check_tutorial_progress(puncher,action,tool,node)
end)

minetest.register_on_dignode(function(pos, oldnode, digger)
    local pname = digger:get_player_name()
    local action = "dig"
    -- Detect if player is wielding a tool for dig
    local tool = digger:get_wielded_item():get_name()
    local node = oldnode.name
    local pos = {}
    local dir = -1
    local key = {}
    tutorial.register_tutorial_action(digger,action,tool,node,pos,dir,key)
    tutorial.check_tutorial_progress(digger,action,tool,node)
end)

minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    local pname = placer:get_player_name()
    local action = "place"
    -- Detect if player is wielding a tool for place
    local tool = placer:get_wielded_item():get_name()
    local node = newnode.name
    local pos = {}
    local dir = -1
    local key = {}
    tutorial.register_tutorial_action(placer,action,tool,node,pos,dir,key)
    tutorial.check_tutorial_progress(placer,action,tool,node)
end)

-- Listener for wield and player control (key strike)
local timer = 0 
minetest.register_globalstep(function(dtime)
    timer = timer + dtime

    -- Listen for wieldedThing
    if timer > 5 and tutorial and tutorial.recordingActive and tutorial.wieldThingListener then
        timer = 0
        local pname = tutorial.recordingPlayer:get_player_name()
        local wieldedThing = tutorial.recordingPlayer:get_wielded_item():get_name()
        if wieldedThing ~= "tutorial:recording_tool" then
            if wieldedThing == "" then wieldedThing = "bare hands" end -- This is needed because no wielded item is an empty string, which conflcits with the default value of tutorialSequence.node
            minetest.chat_send_player(pname,pname.." [Tutorial] Wielded item "..wieldedThing.." was recorded.")
            table.insert(tutorial.tutorialTemp.tutorialSequence.action, "wield")
            table.insert(tutorial.tutorialTemp.tutorialSequence.tool, "")
            table.insert(tutorial.tutorialTemp.tutorialSequence.node, wieldedThing)
            table.insert(tutorial.tutorialTemp.tutorialSequence.pos, {})
            table.insert(tutorial.tutorialTemp.tutorialSequence.dir, -1)
            table.insert(tutorial.tutorialTemp.tutorialSequence.key, {})
            tutorial.tutorialTemp.length = tutorial.tutorialTemp.length + 1
            tutorial.wieldThingListener = false
        end
    end

    -- Listen for keyStrike
    if timer > 1 and tutorial and tutorial.recordingActive and tutorial.keyStrikeListener then
        minetest.chat_send_all(tostring(os.clock()).."[Tutorial] Listening for keystrike, press a player control key now.")
        timer = 0
        local pname = tutorial.recordingPlayer:get_player_name()
        local keyStrike = tutorial.recordingPlayer:get_player_control()
        if keyStrike.up or keyStrike.down or keyStrike.right or keyStrike.left or keyStrike.aux1 or keyStrike.jump or keyStrike.sneak then
            tutorial.tutorialTemp.keys = {}
            for k,v in pairs(keyStrike) do
                if v then table.insert(tutorial.tutorialTemp.keys,k) end
            end
            --minetest.chat_send_all(tostring(_G.dump(keys)))
            local msg = pname.." [Tutorial] Key strike "
            for _,v in pairs(tutorial.tutorialTemp.keys) do msg = msg .. v .. " " end
            local msg = msg .. "was recorded."
            minetest.chat_send_player(pname,msg)
            table.insert(tutorial.tutorialTemp.tutorialSequence.action, "player control")
            table.insert(tutorial.tutorialTemp.tutorialSequence.tool, "")
            table.insert(tutorial.tutorialTemp.tutorialSequence.node, "")
            table.insert(tutorial.tutorialTemp.tutorialSequence.pos, {})
            table.insert(tutorial.tutorialTemp.tutorialSequence.dir, -1)
            table.insert(tutorial.tutorialTemp.tutorialSequence.key, tutorial.tutorialTemp.keys)
            tutorial.tutorialTemp.length = tutorial.tutorialTemp.length + 1
            tutorial.keyStrikeListener = false
        end
    end
end)