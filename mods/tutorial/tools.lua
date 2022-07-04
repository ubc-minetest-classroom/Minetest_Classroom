-- The tutorial book for accessing tutorials
minetest.register_tool("tutorial:tutorialbook" , {
	description = "Tutorial book",
	inventory_image = "tutorialbook.png",
	-- Left-click the tool activates the tutorial menu
	on_use = function (itemstack, user, pointed_thing)
        local pname = user:get_player_name()
		-- Check for privileges
		if tutorial.checkPrivs(user,tutorial.priv_table) then
			tutorial.show_tutorials(user)
		end
	end,
	-- Destroy the book on_drop to keep things tidy
	on_drop = function (itemstack, dropper, pos)
        return
	end,
})

minetest.register_alias("tutorialbook", "tutorial:tutorialbook")
tutorial.tutorialbook = minetest.registered_aliases[tutorialbook] or tutorial.tutorialbook

-- The tutorial recording tool
minetest.register_tool("tutorial:recording_tool", {
    description = "Tutorial Recording Tool",
    _doc_items_longdesc = "This tool can be used to record a sequence of action callbacks (punch, dig, place, position, look directions, and key strikes) that are stored in a tutorial table.",
    _doc_items_usagehelp = "Using the tool (left-click) to start the recording, perform some actions, and use it again to stop the recording sequence. While a recording is active, right-click the tool to access additional recording options.",
    _doc_items_hidden = false,
    tool_capabilities = {},
    range = 100,
    groups = { disable_repair = 1 }, 
    wield_image = "recording_tool.png",
    inventory_image = "recording_tool.png",
    liquids_pointable = false,
    on_use = function(itemstack, user, pointed_thing)
        local pname = user:get_player_name()
        if not tutorial.checkPrivs(user,tutorial.recorder_priv_table) then
            minetest.chat_send_player(pname,pname.." [Tutorial] You do not have privileges to use this tool.")
            return nil
        else
            if not tutorial.recordingActive then
                -- start the recording
                tutorial.recordingActive = true
                minetest.chat_send_player(pname,pname.." [Tutorial] Recording has started! Any actions will now be recorded. Right-click to see more recording options.")
            else
                -- stop the recording and save to mod storage
                tutorial.recordingActive = false
                tutorial.wieldedThingListener = false
                if tutorial.tutorialTemp then
                    tutorial.show_record_fs(user)
                    minetest.chat_send_player(pname,pname.." [Tutorial] Recording has ended!")
                else
                    minetest.chat_send_player(pname,pname.." [Tutorial] No actions were recorded.")
                end
            end
        end
    end,

    on_place = function(itemstack, placer, pointed_thing)
        local pname = placer:get_player_name()
        if not tutorial.checkPrivs(placer,tutorial.recorder_priv_table) then
            minetest.chat_send_player(pname,pname.." [Tutorial] You do not have privileges to use this tool.")
            return nil
        else
            if not tutorial.recordingActive then
                minetest.chat_send_player(pname,pname.." [Tutorial] You need to start an active recording first by left-clicking with the tool.")
                return nil
            else
                tutorial.show_record_options_fs(placer)
            end
        end
    end,

    -- makes the tool undroppable
    on_drop = function (itemstack, dropper, pos)
        return
    end,
})

minetest.register_alias("recording_tool", "tutorial:recording_tool")
tutorial.recording_tool = minetest.registered_aliases[recording_tool] or tutorial.recording_tool