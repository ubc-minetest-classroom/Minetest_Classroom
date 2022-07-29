mc_tutorialFramework = { path = minetest.get_modpath("mc_tf") }

Tutorials = {}

dofile(mc_tutorialFramework.path .. "/Tutorials/Punch-A-Block/main.lua")
dofile(mc_tutorialFramework.path .. "/PopupInfoWindow.lua")

schematicManager.registerSchematicPath("testSchematic", mc_tutorialFramework.path .. "/realmTemplates/TestSchematic")
schematicManager.registerSchematicPath("punchABlockSchematic", mc_tutorialFramework.path .. "/realmTemplates/punchABlock")
schematicManager.registerSchematicPath("movementTutorial", mc_tutorialFramework.path .. "/realmTemplates/MovementTutorial")



pab.CreateBlockFromGroups({ oddly_breakable_by_hand = 3 }, "mc_tf:handBreakable", punchABlock.blockDestroyed)
pab.CreateBlockFromGroups({ crumbly = 1 }, "mc_tf:shovelBreakable", punchABlock.blockDestroyed)
pab.CreateBlockFromGroups({ cracky = 1 }, "mc_tf:pickBreakable", punchABlock.blockDestroyed)
pab.CreateBlockFromGroups({ choppy = 1 }, "mc_tf:axeBreakable", punchABlock.blockDestroyed)




mc_realmportals.newPortal("mc_tf","tf_testRealm", false, "testSchematic")
mc_realmportals.newPortal("mc_tf","tf_movementRealm", false, "movementTutorial")
mc_realmportals.newPortal("mc_tf", "tf_punchABlock", true, "punchABlockSchematic")


----------------------------------
--    TUTORIAL BOOK FUNCTIONS   --
----------------------------------

-- Check for shout priv
local function check_perm(player)
	return minetest.check_player_privs(player:get_player_name(), { shout = true })
end

-- Define a formspec that will describe tutorials and give the option to teleport to selected tutorial realm
local mc_tf_menu = {
	"formspec_version[5]",
	"size[13,10]",
	"box[0.2,8.4;10.2,1.4;#505050]",
	"box[10.7,8.4;2.1,1.4;#C0C0C0]",
	"textarea[5,0.2;7.8,8;;;]",
	"button_exit[11,8.65;1.5,0.9;exit;Exit]",
	"button[0.4,8.7;9.8,0.8;teleport;Teleport to Tutorial]",
	"textlist[0.2,0.2;4.6,8;tutorials;]"
}

local tutorialTable = {}
local is_first = true

local selectedRealm = 0

-- To add a tutorial to the tutorialbook, call addTutorial with the tutorial's name, description, and schematic
function mc_tutorialFramework.addTutorialEntry(name, description, schematic)
        name = name or "Unknown Tutorial"
        description = description or "Unknown Tutorial"
        schematic = schematic or nil

        -- Add tutorial to the text list
		local textlist = mc_tf_menu[#mc_tf_menu]

		if not is_first then
			textlist = textlist:sub(1, textlist:len() - 1) .. "," .. name .. "]"
		else
			textlist = textlist:sub(1, textlist:len() - 1) .. name .. "]"
			is_first = false
		end

        mc_tf_menu[#mc_tf_menu] = textlist

        table.insert(tutorialTable, { name = name, description = description, schematic = schematic})
end

local function show_tutorial_menu(player)
	if check_perm(player) then
		local pname = player:get_player_name()

		local formspec = ""
		for i=1,#mc_tf_menu do
			formspec = formspec .. mc_tf_menu[i]
		end

		minetest.show_formspec(pname, "mc_tf:menu", formspec)
		return true
	end
end

-- The tutorial book for accessing tutorials
minetest.register_tool("mc_tf:tutorialbook" , {
	description = "Tutorial book",
	inventory_image = "tutorial_book.png",
	-- Left-click the tool activates the tutorial menu
	on_use = function (itemstack, user, pointed_thing)
        local pname = user:get_player_name()
		-- Check for shout privileges
		if check_perm(user) then
			local textarea = mc_tf_menu[5]
			textarea = "textarea[5,0.2;7.8,8;;;" .. tutorialTable[1].description .. "]"
			mc_tf_menu[5] = textarea

			show_tutorial_menu(user)
		end
	end,
	-- Destroy the book on_drop to keep things tidy
	on_drop = function(itemstack, dropper, pos)
	end,
})

if minetest.get_modpath("mc_toolhandler") then
	mc_toolhandler.register_tool_manager("mc_tf:tutorialbook", {privs = {shout = true}})
end

minetest.register_alias("tutorialbook", "mc_tf:tutorialbook")
tutorialbook = minetest.registered_aliases[tutorialbook] or tutorialbook

-- Processing the form from the menu
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if string.sub(formname, 1, 5) ~= "mc_tf" then
		return false
	end

	local wait = os.clock()
	while os.clock() - wait < 0.05 do end --popups don't work without this

	-- Menu
	local event = minetest.explode_textlist_event(fields.tutorials)

	if fields.tutorials then
		if event.type == "CHG" then
			local textarea = mc_tf_menu[5]
			textarea = "textarea[5,0.2;7.8,8;;;" .. tutorialTable[event.index].description .. "]"
            selectedRealm = event.index
			mc_tf_menu[5] = textarea
			show_tutorial_menu(player)
		end
	end

    if fields.teleport then
        if selectedEntry ~= 1 and selectedEntry ~= nil then

            Debug.log(selectedEntry)

            local tutorialInfo = tutorialTable[selectedEntry]

            if (tutorialInfo == nil) then
                Debug.log("Tutorial not found")
                return
            end

            local realmName = tutorialInfo.name
            local realmSchematic = tutorialInfo.schematic
            local realm = mc_worldManager.GetCreateInstancedRealm(realmName, player, realmSchematic, true)

            realm:TeleportPlayer(player)
        end
    end
end)

mc_tutorialFramework.addTutorialEntry("Introduction", "Welcome to Minetest Classroom! To access tutorials, select the topic you would like to learn about on the left. Tutorials can also be accessed via portals that will teleport you to the tutorial relevant to the area you are in. To use a portal, stand in the wormhole until it transports you to a new area. Once you are in the tutorial realm, you can use the portal again to return to the area you were previously in.")
mc_tutorialFramework.addTutorialEntry("Test", "testing", "shack")
mc_tutorialFramework.addTutorialEntry("Movement", "This tutorial explains how to walk in different directions, jump, and fly. To enter the tutorial, press the 'Teleport to Tutorial' button below. Once you are in the tutorial realm, you can use the portal again to return to the area you were previously in. If you need a reminder on how to use portals, go to 'Introduction'.", "movementTutorial")
mc_tutorialFramework.addTutorialEntry("Punch a Block", "This tutorial explains how to punch/destroy/mine blocks using various tools. To enter the tutorial, press the 'Teleport to Tutorial' button below. Once you are in the tutorial realm, you can use the portal again to return to the area you were previously in. If you need a reminder on how to use portals, go to 'Introduction'.", "punchABlock")

--    END TUTORIAL FUNCTIONS    --
----------------------------------
