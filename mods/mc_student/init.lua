-- Global variables
minetest_classroom.reports = minetest.get_mod_storage()
minetest_classroom.mc_students = {teachers = {}}

-- Check for shout priv
local function check_perm(player)
	return minetest.check_player_privs(player:get_player_name(), { shout = true })
end

-- Define an initial formspec that will redirect to different formspecs depending on what the teacher wants to do
local mc_student_menu =
		"formspec_version[5]"..
		"size[7,14]"..
		"label[1.7,0.7;What do you want to do?]"..
		"button[2,1.6;3,1.3;spawn;Go to UBC]"..
		"button[2,3.3;3,1.3;accesscode;Join Classroom]"..
		"button[2,5;3,1.3;report;Report]"..
		"button[2,6.7;3,1.3;coordinates;Store Coordinates]"..
		"button[2,8.4;3,1.3;marker;Place a Marker]"..
		"button[2,10.2;3,1.3;taskstudent;View Tasks]"..
		"button_exit[2,11.8;3,1.3;exit;Exit]"

local function show_student_menu(player)
	if check_perm(player) then
		local pname = player:get_player_name()
		minetest.show_formspec(pname, "mc_student:menu", mc_student_menu)
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
local mc_student_report = 
		"formspec_version[5]"..
		"size[7,7]"..
		"label[1.8,0.8;What are you reporting?]"..
		"button[0.7,5.2;2,0.8;back;Back]"..
		"button_exit[2.9,5.2;2,0.8;submit;Submit]"..
		"textarea[0.7,1.5;5.6,3.1;report;; ]"

local function show_report(player)
	local pname = player:get_player_name()
	minetest.show_formspec(pname, "mc_student:report", mc_student_report)
	return true
end

-- Define the Coordinates formspec
local function show_coordinates(player)
	local pname = player:get_player_name()
	mc_student_coordinates = 
		"formspec_version[5]"..
		"size[15,10]"..
		"label[6.3,0.5;Coordinates Stored]"
		
	-- Get the stored coordinates for the player
	local pmeta = player:get_meta()
	pdata = minetest.deserialize(pmeta:get_string("coordinates"))
	if pdata == nil then
		-- No coordinates stored, so return an empty list element
		mc_student_coordinates = 
		mc_student_coordinates.. 
		"textlist[0.3,1;14.4,7.5;;No Coordinates Stored;1;false]"
	else
		mc_student_coordinates = mc_student_coordinates .. "textlist[0.3,1;14.4,7.5;;"
		-- Some coordinates were found, so iterate the list
		pxyz = pdata.coords
		pnotes = pdata.notes
		for i in pairs(pxyz) do
			mc_student_coordinates = mc_student_coordinates .. pxyz[i] .. " " .. pnotes[i] .. ","
		end
		mc_student_coordinates = mc_student_coordinates .. ";1;false]"
	end

	mc_student_coordinates = mc_student_coordinates..
		"button[0.3,9.1;2,0.8;back;Back]"..
		"button[2.5,9.1;2.5,0.8;deleteall;Delete All]"..
		"button[5.2,9.1;2,0.8;record;Record]"..
		"field[7.4,9.1;7.3,0.8;message;Note;Add a note to record at your current location]"
	minetest.show_formspec(pname, "mc_student:coordinates", mc_student_coordinates)
	return true
end

local function record_coordinates(player,message)
	if check_perm(player) then
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
local mc_student_accesscode =
		"formspec_version[5]"..
		"size[5,3]"..
		"label[0.6,0.5;Enter an Access Code]"..
		"pwdfield[0.5,0.9;3.9,0.8;accesscode;]"..
		"button_exit[0.9,2;3,0.8;submit;Submit]"..
		"button_exit[4.4,0;0.6,0.5;exit;X]"

local function show_accesscode(player)
	if check_perm(player) then
		local pname = player:get_player_name()
		minetest.show_formspec(pname, "mc_student:accesscode", mc_student_accesscode)
		return true
	end
end

local mc_student_accesscode_fail = 
		"formspec_version[5]"..
		"size[5,4.2]"..
		"label[0.6,0.5;Enter Your Access Code]"..
		"pwdfield[0.5,0.9;3.9,0.8;accesscode;]"..
		"button_exit[0.9,2;3,0.8;submit;Submit]"..
		"label[0.9,3.2;Invalid access code.]"..
		"label[1.2,3.7;Please try again.]"..
		"button_exit[4.4,0;0.6,0.5;exit;X]"
		
local function show_accesscode_fail(player)
	if check_perm(player) then
		local pname = player:get_player_name()
		minetest.show_formspec(pname, "mc_student:accesscode_fail", mc_student_accesscode_fail)
		return true
	end
end

-- Define place a marker formspec
local mc_student_marker =
		"formspec_version[5]"..
		"size[7,6.5]"..
		"position[0.3,0.5]"..
		"label[1.8,0.8;Add text to your marker]"..
		"button[0.7,5.2;2,0.8;back;Back]"..
		"button_exit[2.9,5.2;2,0.8;submit;Submit]"..
		"textarea[0.7,1.5;5.6,3.1;message;; ]"

local function show_marker(player)
	if check_perm(player) then
		local pname = player:get_player_name()
		minetest.show_formspec(pname, "mc_student:marker", mc_student_marker)
		return true
	end
end

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
                        -- TODO: dynamically extract the static spawn point from the minetest.conf file
                        -- local cmeta = Settings(minetest.get_modpath("mc_teacher").."/maps/"..map..".conf")
                        -- local spawn_pos_x = tonumber(cmeta:get("spawn_pos_x"))
                        -- local spawn_pos_y = tonumber(cmeta:get("spawn_pos_y"))
                        -- local spawn_pos_z = tonumber(cmeta:get("spawn_pos_z"))
                        local spawn_pos = {
                                x = 1426,
                                y = 92,
                                z = 1083,
                        }
                        player:set_pos(spawn_pos)
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

			if teachers ~= "" then
				msg = '[REPORT] ' .. msg .. " (teachers online: " .. teachers:sub(1, -3) .. ")"
			end

			-- Send report to any teacher currently connected
			for teacher in pairs(minetest_classroom.mc_students.teachers) do
				minetest.chat_send_player(teacher, minetest.colorize("#FF00FF", msg))
			end
			
			-- Archive the report in mod storage
			local key = pname.." "..tostring(os.date("%d-%m-%Y %H:%M:%S"))
			minetest_classroom.reports:set_string(key, minetest.write_json(fields.report))
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
		temp = minetest.deserialize(minetest_classroom.classrooms:get_string("classrooms"))
		-- Get the classroom accesscodes
		loc = check_access_code(fields.accesscode,temp.access_code)
		if loc then
			-- Check if the student is currently registered for this course
			pmeta = player:get_meta()
			pdata = minetest.deserialize(pmeta:get_string("classrooms"))
			-- Validate against modstorage
			mdata = minetest.deserialize(minetest_classroom.classrooms:get_string("classrooms"))
			if pdata == nil then
				-- This is the first time the student registers for any course
				classroomdata = {
					course_code = { mdata.course_code[loc] },
					section_number = { mdata.section_number[loc] },
					start_year = { mdata.start_year[loc] },
					start_month = { mdata.start_month[loc] },
					start_day = { mdata.start_day[loc] },
					end_year = { mdata.end_year[loc] },
					end_month = { mdata.end_month[loc] },
					end_day = { mdata.end_day[loc] },
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
				classroomdata = {
					course_code = pdata.course_code,
					section_number = pdata.section_number,
					start_year = pdata.start_year,
					start_month = pdata.start_month,
					start_day = pdata.start_day,
					end_year = pdata.end_year,
					end_month = pdata.end_month,
					end_day = pdata.end_day,
				}
			end
			
			-- Check if the access code is expired
			if tonumber(mdata.end_year[loc]) < tonumber(os.date("%Y")) and months[mdata.end_month[loc]] < tonumber(os.date("%m")) and tonumber(mdata.end_day[loc]) < tonumber(os.date("%d")) then
				minetest.chat_send_player(pname,pname..": The access code you entered has expired. Please contact your instructor.")
			else
				-- Send the student to the classroom spawn pos
				player:set_pos(mdata.spawn_pos[loc])
			end
		else
			show_accesscode_fail(player)
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
minetest.register_tool("mc_student:notebook" , {
	description = "Notebook for students",
	inventory_image = "notebook.png",
	-- Left-click the tool activates the teacher menu
	on_use = function (itemstack, user, pointed_thing)
        local pname = user:get_player_name()
		-- Check for shout privileges
		if check_perm(user) then
			show_student_menu(user)
		end
	end,
	-- Destroy the controller on_drop to keep things tidy
	on_drop = function (itemstack, dropper, pos)
		minetest.set_node(pos, {name="air"})
	end,
})

-- Give the notebook to any player who joins with shout privileges or take away the controller if they do not have shout
minetest.register_on_joinplayer(function(player)
	local inv = player:get_inventory()
	if inv:contains_item("main", ItemStack("mc_student:notebook")) then
		-- Player has the notebook
		if check_perm(player) then
			-- The player should have the notebook
			return
		else
			-- The player should not have the notebook
			player:get_inventory():remove_item('main', 'mc_student:notebook')
		end
	else
		-- Player does not have the notebook
		if check_perm(player) then
			-- The player should have the notebook
			player:get_inventory():add_item('main', 'mc_student:notebook')
		else
			-- The player should not have the notebook
			return
		end
	end
end)

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
	if check_perm(player) then
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
