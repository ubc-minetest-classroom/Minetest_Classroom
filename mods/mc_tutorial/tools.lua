-- The tutorial book for accessing tutorials
minetest.register_tool("mc_tutorial:tutorialbook" , {
	description = "Tutorial book",
	inventory_image = "mc_tutorial_tutorialbook.png",
    _mc_tool_privs = mc_tutorial.player_priv_table,
	-- Left-click the tool activates the tutorial menu
	on_use = function (itemstack, user, pointed_thing)
        local pname = user:get_player_name()
		-- Check for privileges
		if mc_tutorial.check_privs(user,mc_tutorial.player_priv_table) then
			mc_tutorial.show_tutorials(user)
		end
	end,
	-- Destroy the book on_drop to keep things tidy
	on_drop = function (itemstack, dropper, pos)
        return
	end,
})

minetest.register_alias("tutorialbook", "mc_tutorial:tutorialbook")
mc_tutorial.tutorialbook = minetest.registered_aliases[tutorialbook] or mc_tutorial.tutorialbook

local function open_recording_menu(itemstack, placer, pointed_thing)
    local pname = placer:get_player_name()
    if not mc_tutorial.check_privs(placer,mc_tutorial.recorder_priv_table) then
        minetest.chat_send_player(pname, "[Tutorial] You do not have privileges to use this tool.")
        return nil
    else
        if not mc_tutorial.record.active[pname] then
            minetest.chat_send_player(pname, "[Tutorial] You need to start an active recording first by left-clicking with the tool.")
            return nil
        else
            mc_tutorial.show_record_options_fs(placer)
        end
    end
end

-- The tutorial recording tool
minetest.register_tool("mc_tutorial:recording_tool", {
    description = "Tutorial Recording Tool",
    _doc_items_longdesc = "This tool can be used to record a sequence of action callbacks (punch, dig, place, position, look directions, and key strikes) that are stored in a tutorial table.",
    _doc_items_usagehelp = "Using the tool (left-click) to start the recording, perform some actions, and use it again to stop the recording sequence. While a recording is active, right-click the tool to access additional recording options.",
    _doc_items_hidden = false,
    _mc_tool_privs = mc_tutorial.recorder_priv_table,
    tool_capabilities = {},
    range = 100,
    groups = { disable_repair = 1 }, 
    wield_image = "mc_tutorial_recording_tool.png",
    inventory_image = "mc_tutorial_recording_tool.png",
    liquids_pointable = false,
    on_use = function(itemstack, user, pointed_thing)
        local pname = user:get_player_name()
        if not mc_tutorial.check_privs(user,mc_tutorial.recorder_priv_table) then
            minetest.chat_send_player(pname, "[Tutorial] You do not have privileges to use this tool.")
            return nil
        else
            if not mc_tutorial.record.active[pname] then
                -- start the recording
                mc_tutorial.record.active[pname] = true
                minetest.chat_send_player(pname, "[Tutorial] Recording has started! Any actions will now be recorded. Right-click to see more recording options.")
            else
                -- stop the recording and save to mod storage
                mc_tutorial.record.active[pname] = nil
                mc_tutorial.record.listener.wield[pname] = nil
                mc_tutorial.record.listener.key[pname] = nil
                if mc_tutorial.record.temp[pname] then
                    mc_tutorial.show_record_fs(user)
                    minetest.chat_send_player(pname, "[Tutorial] Recording has ended!")
                else
                    minetest.chat_send_player(pname, "[Tutorial] No actions were recorded.")
                end
            end
        end
    end,

    on_secondary_use = open_recording_menu,
    on_place = open_recording_menu,

    -- makes the tool undroppable
    on_drop = function (itemstack, dropper, pos)
        return
    end,
})

minetest.register_alias("recording_tool", "mc_tutorial:recording_tool")
mc_tutorial.recording_tool = minetest.registered_aliases[recording_tool] or mc_tutorial.recording_tool