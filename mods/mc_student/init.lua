-- Global variables
minetest_classroom.reports = minetest.get_mod_storage()
minetest_classroom.mc_students = {teachers = {}}

-- Local variables
local tool_name = "mc_student:notebook"
local priv_table = {interact = true}

-- Split pos in coordlist from character "x=1 y=2 z=3" to numeric table {1,2,3}
local function pos_split (inputstr)
	local t={}
	for str in string.gmatch(inputstr, "([^=%s]+)") do
		table.insert(t, str)
	end
	local tt={x=tonumber(t[2]),z=tonumber(t[6]),y=tonumber(t[4])}
	return tt
end

-- Define an initial formspec that will redirect to different formspecs depending on what the student wants to do
local mc_student_menu = {
	"formspec_version[5]",
	"size[10,9]",
	"label[3.1,0.7;What do you want to do?]",
	"button[1,1.6;3.8,1.3;spawn;Go Home]",
	"button[5.2,1.6;3.8,1.3;accesscode;Join Classroom]",
	"button[1,3.3;3.8,1.3;coordinates;My Coordinates]",
	"button[5.2,3.3;3.8,1.3;marker;Place a Marker]",
	"button[1,5;3.8,1.3;taskstudent;View Tasks]",
	"button[5.2,5;3.8,1.3;report;Report]",
	"button_exit[3.1,6.7;3.8,1.3;exit;Exit]"
}

local function show_student_menu(player)
	if mc_helpers.checkPrivs(player,priv_table) then
		local pname = player:get_player_name()
		minetest.show_formspec(pname, "mc_student:menu", table.concat(mc_student_menu,""))
		return true
	end
end

minetest.register_on_joinplayer(function(player)
	if minetest.check_player_privs(player, { teacher = true }) then
		minetest_classroom.mc_students.teachers[player:get_player_name()] = true
	end
end)

minetest.register_on_leaveplayer(function(player)
	minetest_classroom.mc_students.teachers[player:get_player_name()] = nil
end)

-- Define the Report formspec
local mc_student_report = {
	"formspec_version[5]",
	"size[7,7]",
	"label[1.8,0.8;What are you reporting?]",
	"button[0.7,5.2;2,0.8;back;Back]",
	"button_exit[2.9,5.2;2,0.8;submit;Submit]",
	"textarea[0.7,1.5;5.6,3.1;report;; ]"
}

local function show_report(player)
	local pname = player:get_player_name()
	minetest.show_formspec(pname, "mc_student:report", table.concat(mc_student_report,""))
	return true
end

-- Define the Coordinates formspec
local function show_coordinates(player)
	local pname = player:get_player_name()
	mc_student_coordinates = {
		"formspec_version[5]",
		"size[15,10]",
		"label[6.3,0.5;Coordinates Stored]"
	}

	-- Get the stored coordinates for the player
	local pmeta = player:get_meta()
	pdata = minetest.deserialize(pmeta:get_string("coordinates"))
	if pdata == nil then
		-- No coordinates stored, so return an empty list element
		mc_student_coordinates[#mc_student_coordinates + 1] = "textlist[0.3,1;14.4,7.5;;No Coordinates Stored;1;false]"
	else
		mc_student_coordinates[#mc_student_coordinates + 1] = "textlist[0.3,1;14.4,7.5;coordlist;"
		-- Some coordinates were found, so iterate the list
		pxyz = pdata.coords
		pnotes = pdata.notes
		for i in pairs(pxyz) do
			mc_student_coordinates[#mc_student_coordinates + 1] = pxyz[i] .. " " .. pnotes[i] .. ","
		end
		mc_student_coordinates[#mc_student_coordinates + 1] = ";1;false]"
	end

	mc_student_coordinates[#mc_student_coordinates + 1] = "button[0.1,9.1;1.6,0.8;back;Back]"
	mc_student_coordinates[#mc_student_coordinates + 1] = "button[1.9,9.1;1.4,0.8;go;Go]"
	mc_student_coordinates[#mc_student_coordinates + 1] = "button[3.5,9.1;1.9,0.8;deleteall;Delete All]"
	mc_student_coordinates[#mc_student_coordinates + 1] = "button[5.6,9.1;1.6,0.8;record;Record]"
	mc_student_coordinates[#mc_student_coordinates + 1] = "field[7.4,9.1;7.3,0.8;message;Note;Add a note to record at your current location]"
	minetest.show_formspec(pname, "mc_student:coordinates", table.concat(mc_student_coordinates,""))
	return true
end

local function record_coordinates(player,message)
	if mc_helpers.checkPrivs(player,priv_table) then
		local pname = player:get_player_name()
		pmeta = player:get_meta()
		local pos = player:get_pos()
		temp = minetest.deserialize(pmeta:get_string("coordinates"))
		if temp == nil then
			datanew = {
				coords = {"x="..math.floor(pos.x).." z="..math.floor(pos.y).." y="..math.floor(pos.z), },
				notes = { message, },
			}
		else
			table.insert(temp.coords, "x="..math.floor(pos.x).." z="..math.floor(pos.y).." y="..math.floor(pos.z))
			table.insert(temp.notes, message)
			datanew = {coords = temp.coords, notes = temp.notes, }
		end
		pmeta:set_string("coordinates", minetest.serialize(datanew))
		temp = nil
		minetest.chat_send_player(pname,pname..": Your position was recorded in your notebook.")
		-- Update the formspec
		show_coordinates(player)
	end
end

-- Define the Access Code formspec
local mc_student_accesscode = {
	"formspec_version[5]",
	"size[5,3]",
	"label[0.6,0.5;Enter an Access Code]",
	"pwdfield[0.5,0.9;3.9,0.8;accesscode;]",
	"button_exit[0.9,2;3,0.8;submit;Submit]",
	"button_exit[4.4,0;0.6,0.5;exit;X]"
}

local function show_accesscode(player)
	if mc_helpers.checkPrivs(player,priv_table) then
		local pname = player:get_player_name()
		minetest.show_formspec(pname, "mc_student:accesscode", table.concat(mc_student_accesscode,""))
		return true
	end
end

local mc_student_accesscode_fail = {
	"formspec_version[5]",
	"size[5,4.2]",
	"label[0.6,0.5;Enter Your Access Code]",
	"pwdfield[0.5,0.9;3.9,0.8;accesscode;]",
	"button_exit[0.9,2;3,0.8;submit;Submit]",
	"label[0.9,3.2;Invalid access code.]",
	"label[1.2,3.7;Please try again.]",
	"button_exit[4.4,0;0.6,0.5;exit;X]"
}

local function show_accesscode_fail(player)
	if mc_helpers.checkPrivs(player,priv_table) then
		local pname = player:get_player_name()
		minetest.show_formspec(pname, "mc_student:accesscode_fail", table.concat(mc_student_accesscode_fail,""))
		return true
	end
end

-- Define place a marker formspec
local mc_student_marker = {
	"formspec_version[5]",
	"size[7,6.5]",
	"position[0.3,0.5]",
	"label[1.8,0.8;Add text to your marker]",
	"button[0.7,5.2;2,0.8;back;Back]",
	"button_exit[2.9,5.2;2,0.8;submit;Submit]",
	"textarea[0.7,1.5;5.6,3.1;message;; ]"
}

	local function show_marker(player)
	if mc_helpers.checkPrivs(player,priv_table) then
		local pname = player:get_player_name()
		minetest.show_formspec(pname, "mc_student:marker", table.concat(mc_student_marker,""))
		return true
	end
end

----------------------------------
--    TUTORIAL BOOK FUNCTIONS   --
----------------------------------

-- Define a formspec that will describe tutorials and give the option to teleport to selected tutorial realm
local mc_student_tutorial_menu = {
	"formspec_version[5]",
	"size[13,10]",
	"button[0.2,0.2;4.6,0.8;intro;Introduction]",
	"box[0.2,8.4;10.2,1.4;#505050]",
	"button[0.2,1.2;4.6,0.8;mov;Movement]",
	"button[0.2,2.2;4.6,0.8;punch;Punch A Block]",
	"textarea[5,0.2;7.8,8;text;;Welcome to Minetest Classroom! To access tutorials, select the topic you would like to learn about on the left. Tutorials can also be accessed via portals that will teleport you to the tutorial relevant to the area you are in. To use a portal, stand in the wormhole until it transports you to a new area. Once you are in the tutorial realm, you can use the portal again to return to the area you were previously in.]",
	"button[0.4,8.7;9.8,0.8;teleport;Teleport to Tutorial]",
	"box[10.7,8.4;2.1,1.4;#C0C0C0]",
	"button_exit[11,8.65;1.5,0.9;exit;Exit]"
}

local function show_tutorial_menu(player)
	if mc_helpers.checkPrivs(player,priv_table) then
		local pname = player:get_player_name()
		minetest.show_formspec(pname, "mc_student:tutorial_menu", table.concat(mc_student_tutorial_menu,""))
		return true
	end
end

mc_student_mov = {
	"formspec_version[5]",
	"size[13,10]",
	"button[0.2,0.2;4.6,0.8;intro;Introduction]",
	"box[0.2,8.4;10.2,1.4;#505050]",
	"button[0.2,1.2;4.6,0.8;mov;Movement]",
	"button[0.2,2.2;4.6,0.8;punch;Punch A Block]",
	"textarea[5,0.2;7.8,8;text;;This tutorial explains how to walk in different directions, jump, and fly. To enter the tutorial, press the 'Teleport to Tutorial' button below. Once you are in the tutorial realm, you can use the portal again to return to the area you were previously in. If you need a reminder on how to use portals, go to 'Introduction'.]",
	"button[0.4,8.7;9.8,0.8;teleport;Teleport to Tutorial]",
	"box[10.7,8.4;2.1,1.4;#C0C0C0]",
	"button_exit[11,8.65;1.5,0.9;exit;Exit]"
}

local function show_mov(player)
	if mc_helpers.checkPrivs(player,priv_table) then
		local pname = player:get_player_name()
		minetest.show_formspec(pname, "mc_student:mov", table.concat(mc_student_mov,""))
		return true
	end
end

mc_student_punch = {
    "formspec_version[5]",
	"size[13,10]" ,
	"button[0.2,0.2;4.6,0.8;intro;Introduction]",
	"box[0.2,8.4;10.2,1.4;#505050]",
	"button[0.2,1.2;4.6,0.8;mov;Movement]",
	"button[0.2,2.2;4.6,0.8;punch;Punch A Block]",
	"textarea[5,0.2;7.8,8;text;;This tutorial explains how to punch and place blocks, which will allow you to add materials to your inventory and build. To enter the tutorial, press the 'Teleport to Tutorial' button below. Once you are in the tutorial realm, you can use the portal again to return to the area you were previously in. If you need a reminder on how to use portals, go to 'Introduction'.]",
	"button[0.4,8.7;9.8,0.8;teleport;Teleport to Tutorial]",
	"box[10.7,8.4;2.1,1.4;#C0C0C0]",
	"button_exit[11,8.65;1.5,0.9;exit;Exit]"
}

local function show_punch(player)
	if mc_helpers.checkPrivs(player,priv_table) then
		local pname = player:get_player_name()
		minetest.show_formspec(pname, "mc_student:punch", table.concat(mc_student_punch,""))
		return true
	end
end

----------------------------------
--    END TUTORIAL FUNCTIONS    --
----------------------------------

-- Processing the form from the menu
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if string.sub(formname, 1, 10) ~= "mc_student" then
		return false
	end

	local wait = os.clock()
	while os.clock() - wait < 0.05 do end --popups don't work without this

	-- Menu
	if formname == "mc_student:menu" then
		if fields.spawn then
			local spawnRealm = mc_worldManager.GetSpawnRealm()
			spawnRealm:TeleportPlayer(player)
        elseif fields.report then
			show_report(player)
		elseif fields.coordinates then
			show_coordinates(player)
		elseif fields.accesscode then
			show_accesscode(player)
		elseif fields.marker then
			show_marker(player)
		elseif fields.taskstudent then
			local pname = player:get_player_name()
			if minetest_classroom.currenttask ~= nil then
				minetest.show_formspec(pname, "task:instructions", minetest_classroom.currenttask)
			else
				minetest.chat_send_player(pname,pname..": No task was found. Message your instructor if you were expecting a task.")
			end
		end
	end

	if formname == "mc_student:report" then
		if fields.back then
			show_student_menu(player)
		-- Checking for nil (caused by player pressing escape instead of Back) ensures the game does not crash
		elseif fields.report ~= " " and fields.report ~= nil then
			local pname = player:get_player_name()

			-- Count the number of words, by counting for replaced spaces
			-- Number of spaces = Number of words - 1
			local _, count = string.gsub(fields.report, " ", "")
			if count == 0 then
				return false, "If you're reporting a player, you should" ..
					" also include a reason why."
			end

			local msg = pname .. " reported: " .. fields.report

			-- Append list of teachers in-game
			local teachers = ""
			for teacher in pairs(minetest_classroom.mc_students.teachers) do
				teachers = teachers .. teacher .. ", "
			end

			if #minetest_classroom.mc_students.teachers then
				local msg = '[REPORT] ' .. msg .. " (teachers online: " .. teachers:sub(1, -3) .. ")"
				-- Send report to any teacher currently connected
				for teacher in pairs(minetest_classroom.mc_students.teachers) do
					minetest.chat_send_player(teacher, minetest.colorize("#FF00FF", msg))
					minetest.sound_play("report_alert", {to_player = teacher, gain = 1.0, pitch = 1.0,}, true)

				end
			end

			-- Archive the report in mod storage
			local key = pname.." "..tostring(os.date("%d-%m-%Y %H:%M:%S"))
			minetest_classroom.reports:set_string(key,
			minetest.write_json(fields.report))

			-- Archive the report in the chatlog
			chatlog.write_log(pname,'[REPORT] '..fields.report)
		elseif fields.report == nil then
			return true
		else
			minetest.chat_send_player(player:get_player_name(),minetest.colorize("#FF0000","Error: Please add a message to your report."))
		end
	end

	if formname == "mc_student:marker" then
		if fields.back then
			show_student_menu(player)
		elseif fields.message then
			place_marker(player,fields.message)
		elseif fields.message == nil then
			return true
		end
	end

	if formname == "mc_student:coordinates" then
		if fields.back then
			show_student_menu(player)
		elseif fields.record then
			record_coordinates(player,fields.message)
		elseif fields.coordlist then
			local event = minetest.explode_textlist_event(fields.coordlist)
		    	if event.type == "CHG" then
			-- "CHG" = something is selected in the list
				context.selected = event.index
		    	end
		elseif fields.go then
			local pname = player:get_player_name()
			local pmeta = player:get_meta()
			if not context.selected then
				context.selected = 1
			end
		    	local temp = minetest.deserialize(pmeta:get_string("coordinates"))
		    	local new_pos_char = temp.coords[context.selected]
			local new_pos_tab = pos_split(new_pos_char)
		    	player:set_pos(new_pos_tab)
		elseif fields.deleteall then
			local pmeta = player:get_meta()
			pmeta:set_string("coordinates", nil)
			show_coordinates(player)
		end
	end

	if formname == "mc_student:accesscode" or formname == "mc_student:accesscode_fail" then
		if fields.exit then
			return
		end

		local pname = player:get_player_name()

		-- Get the classrooms from modstorage
		local temp = minetest.deserialize(minetest_classroom.classrooms:get_string("classrooms"))

		if temp ~= nil then
			-- Get the classroom accesscodes
			local loc = check_access_code(fields.accesscode,temp.access_code)
			if loc then
				-- Check if the student is currently registered for this course
				local pmeta = player:get_meta()
				local pdata = minetest.deserialize(pmeta:get_string("classrooms"))
				-- Validate against modstorage
				local mdata = minetest.deserialize(minetest_classroom.classrooms:get_string("classrooms"))
				if pdata == nil then
					-- This is the first time the student registers for any course
					local classroomdata = {
						course_code = { mdata.course_code[loc] },
						section_number = { mdata.section_number[loc] },
						start_year = { mdata.start_year[loc] },
						start_month = { mdata.start_month[loc] },
						start_day = { mdata.start_day[loc] },
						end_year = { mdata.end_year[loc] },
						end_month = { mdata.end_month[loc] },
						end_day = { mdata.end_day[loc] },
						realm_id = { mdata.realm_id[loc] },
					}
					pmeta:set_string("classrooms", minetest.serialize(classroomdata))
				else
					-- Student has already registered for another classroom
					table.insert(pdata.course_code, mdata.course_code[loc])
					table.insert(pdata.section_number, mdata.section_number[loc])
					table.insert(pdata.start_year, mdata.start_year[loc])
					table.insert(pdata.start_month, mdata.start_month[loc])
					table.insert(pdata.start_day, mdata.start_day[loc])
					table.insert(pdata.end_year, mdata.end_year[loc])
					table.insert(pdata.end_month, mdata.end_month[loc])
					table.insert(pdata.end_day, mdata.end_day[loc])
					local classroomdata = {
						course_code = pdata.course_code,
						section_number = pdata.section_number,
						start_year = pdata.start_year,
						start_month = pdata.start_month,
						start_day = pdata.start_day,
						end_year = pdata.end_year,
						end_month = pdata.end_month,
						end_day = pdata.end_day,
						realm_id = pdata.realm_id,
					}
				end

				-- Check if the access code is expired
				if tonumber(mdata.end_year[loc]) < tonumber(os.date("%Y")) and months[mdata.end_month[loc]] < tonumber(os.date("%m")) and tonumber(mdata.end_day[loc]) < tonumber(os.date("%d")) then
					minetest.chat_send_player(pname,pname..": The access code you entered has expired. Please contact your instructor.")
				else

                    local realm = Realm.GetRealm(mdata.realm_id[loc])

                    if (realm ~= nil) then

                        local students = realm:get_data("students")
                        if students == nil then
                            students = {}
                        end
                        students[player:get_player_name()] = true
                        realm:set_data("students", students)

                        realm:TeleportPlayer(player)
                        minetest.chat_send_player(pname, pname .. ": You have been teleported to the classroom.")
                    end
				end
			else
				show_accesscode_fail(player)
			end
		else
			return
		end
	end

	if formname == "mc_student:tutorial_menu" then
        if fields.mov then
			show_mov(player)
		elseif fields.punch then
			show_punch(player)
		end
	end

	if formname == "mc_student:mov" then
        if fields.intro then
            show_tutorial_menu(player)
		elseif fields.punch then
			show_punch(player)
		end
	end

	if formname == "mc_student:punch" then
        if fields.intro then
            show_tutorial_menu(player)
		elseif fields.mov then
			show_mov(player)
		end
	end
end)

function check_access_code(submitted, codes)
	local found = false
	local loc = 1
	for _,v in pairs(codes) do
	    if v == submitted then
		    local found = true
		    return loc
	    end
	    loc = loc + 1
	end
    return found
end

-- The student notebook for accessing the student actions
minetest.register_tool(tool_name , {
	description = "Notebook for students",
	inventory_image = "notebook.png",
	-- Left-click the tool activates the teacher menu
	on_use = function (itemstack, player, pointed_thing)
        local pname = player:get_player_name()
		-- Check for adequate privileges
		if mc_helpers.checkPrivs(player,priv_table) then
			show_student_menu(player)
		end
	end,
	-- Destroy the controller on_drop to keep things tidy
	on_drop = function(itemstack, dropper, pos)
	end,
})

if minetest.get_modpath("mc_toolhandler") then
	mc_toolhandler.register_tool_manager(tool_name, {privs = priv_table})
end

-- Functions and variables for placing markers
hud = mhud.init()
markers = {}
local MARKER_LIFETIME = 30
local MARKER_RANGE = 150

function add_marker(pname, message, pos, owner)
	if not hud:get(pname, "marker_" .. owner) then
		hud:add(pname, "marker_" .. owner, {
			hud_elem_type = "waypoint",
			world_pos = pos,
			precision = 1,
			color = 0xFF0000, -- red
			text = message
		})
	else
		hud:change(pname, "marker_" .. owner, {
			world_pos = pos,
			text = message
		})
	end
end

function markers.add(pname, msg, pos)

	if markers[pname] then
		markers[pname].timer:cancel()
	end

	markers[pname] = {
		msg = msg, pos = pos,
		timer = minetest.after(MARKER_LIFETIME, markers.remove, pname),
	}

	for _, player in pairs(minetest.get_connected_players()) do
		add_marker(player, msg, pos, pname)
	end
end

function markers.remove(pname)
	if markers[pname] then
		markers[pname].timer:cancel()

		for _, player in pairs(minetest.get_connected_players()) do
			hud:remove(player, "marker_" .. pname)
		end

		markers[pname] = nil
	end
end

-- Legacy code, keep for convenience
minetest.register_chatcommand("m", {
	description = "Place a marker in your look direction",
	privs = {interact = true, shout = true},
	func = function(name, param)

		local player = minetest.get_player_by_name(name)
		local pos1 = vector.offset(player:get_pos(), 0, player:get_properties().eye_height, 0)

		if param == "" then
			param = "Look here!"
		end

		local ray = minetest.raycast(
			pos1, vector.add(pos1, vector.multiply(player:get_look_dir(), MARKER_RANGE),
			true, false
		))
		local pointed = ray:next()

		if pointed and pointed.type == "object" and pointed.ref == player then
			pointed = ray:next()
		end

		if not pointed then
			return false, "Can't find anything to mark, too far away!"
		end

		local message = string.format("m [%s]: %s", name, param)
		local pos

		if pointed.type == "object" then
			local concat
			local obj = pointed.ref
			local entity = obj:get_luaentity()

			-- If object is a player, append player name to display text
			-- Else if obj is item entity, append item description and count to str.
			if obj:is_player() then
				concat = obj:get_player_name()
			elseif entity then
				if entity.name == "__builtin:item" then
					local stack = ItemStack(entity.itemstring)
					local itemdef = minetest.registered_items[stack:get_name()]

					-- Fallback to itemstring if description doesn't exist
					concat = itemdef.description or entity.itemstring
					concat = concat .. " " .. stack:get_count()
				end
			end

			pos = obj:get_pos()
			if concat then
				message = message .. " <" .. concat .. ">"
			end
		else
			pos = pointed.under
		end

		markers.add(name, message, pos)

		return true, "Marker is placed!"
	end
})

function place_marker(player,message)
	if mc_helpers.checkPrivs(player,priv_table) then
		local pname = player:get_player_name()
		local pos1 = vector.offset(player:get_pos(), 0, player:get_properties().eye_height, 0)

		local ray = minetest.raycast(
			pos1, vector.add(pos1, vector.multiply(player:get_look_dir(), MARKER_RANGE),
			true, false
		))
		local pointed = ray:next()

		if message == "" then
			message = "Look here!"
		end

		if pointed and pointed.type == "object" and pointed.ref == player then
			pointed = ray:next()
		end

		if not pointed then
			return false, minetest.chat_send_player(pname,pname..": Nothing found or too far away.")
		end

		local message = string.format("m [%s]: %s", pname, message)
		local pos

		if pointed.type == "object" then
			local concat
			local obj = pointed.ref
			local entity = obj:get_luaentity()

			-- If object is a player, append player name to display text
			-- Else if obj is item entity, append item description and count to str.
			if obj:is_player() then
				concat = obj:get_player_name()
			elseif entity then
				if entity.name == "__builtin:item" then
					local stack = ItemStack(entity.itemstring)
					local itemdef = minetest.registered_items[stack:get_name()]

					-- Fallback to itemstring if description doesn't exist
					concat = itemdef.description or entity.itemstring
					concat = concat .. " " .. stack:get_count()
				end
			end

			pos = obj:get_pos()
			if concat then
				message = message .. " <" .. concat .. ">"
			end
		else
			pos = pointed.under
		end

		markers.add(pname, message, pos)
		minetest.chat_send_player(pname,pname..": You placed a marker.")
		return true
	else
		minetest.chat_send_player(pname,pname..": You are not allowed to place markers. Please submit a report from your notebook to request this privilege.")
	end
end
