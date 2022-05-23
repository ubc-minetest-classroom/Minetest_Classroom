local S = minetest_classroom.S
local FS = minetest_classroom.FS
context = {}
local infos = {
	{
		title = S"Mute?",
		type = "priv",
		privs = { shout = true },
	},
	{
		title = S"Fly?",
		type = "priv",
		privs = { fly = true },
	},
	{
		title = S"Freeze?",
		type = "priv",
		privs = { fast = true },
	},
	{
		title = S"Dig?",
		type = "priv",
		privs = { interact = true },
	},
}

local magnify = dofile(minetest.get_modpath("magnify") .. "/exports.lua")

local function get_group(context)
	if context and context.groupname then
		return minetest_classroom.get_group_students(context.groupname)
	else
		return minetest_classroom.get_students()
	end
end

-- Check for teacher priv
local function check_perm(player)
	return minetest.check_player_privs(player:get_player_name(), { teacher = true })
end

-- Label the teacher in red
minetest.register_on_joinplayer(function(player)
    if check_perm(player) then
        player:set_nametag_attributes({color = {r = 255, g = 0,   b = 0}})
    end
end)

-- Define an initial formspec that will redirect to different formspecs depending on what the teacher wants to do
local mc_teacher_menu =
	"formspec_version[5]"..
	"size[10,9]"..
	"label[3.2,0.7;What do you want to do?]"..
	"button[1,1.6;3.8,1.3;spawn;Go to UBC]"..
	"button[5.2,1.6;3.8,1.3;tasks;Manage Tasks]"..
	"button[1,3.3;3.8,1.3;lessons;Manage Lessons]"..
	"button[5.2,3.3;3.8,1.3;players;Manage Players]"..
	"button[1,5;3.8,1.3;classrooms;Manage Classrooms]"..
	"button[5.2,5;3.8,1.3;species;Plant Compendium]"..
	"button[1,6.7;3.8,1.3;mail;Teacher Mail]"..
	"button_exit[5.2,6.7;3.8,1.3;exit;Exit]"

local function show_teacher_menu(player)
	if check_perm(player) then
		local pname = player:get_player_name()
		minetest.show_formspec(pname, "mc_teacher:menu", mc_teacher_menu)
		return true
	end
	
end

-- Define the Manage Tasks formspec (teacher-view)
local mc_teacher_tasks = 
		"formspec_version[5]"..
        "size[10,13]"..
        "field[0.375,0.75;9.25,0.8;task;Enter task below;]"..
        "textarea[0.375,2.5;9.25,7;instructions;Enter instructions below;]"..
        "field[0.375,10.5;9.25,0.8;timer;Enter timer for task in seconds (0 or blank = no timer);]"..
		"button[0.375,11.5;2,0.8;back;Back]"..
        "button_exit[2.575,11.5;2,0.8;submit;Submit]"

local function show_tasks(player)
	if check_perm(player) then
		local pname = player:get_player_name()
		minetest.show_formspec(pname, "mc_teacher:tasks", mc_teacher_tasks)
		return true
	end
end

-- NEW TEACHER VIEWER  // have to connect them // edit to variables 
-- manage species button in main menu  --> leads to formspec where:

-- Set up a task timer
local hud = mhud.init()
local timer = nil
task_timer = {}
function timer_func(time_left)
	if time_left == 0 then
		task_timer.finish()
		return
    elseif time_left == 11 then
        minetest.sound_play("timer_bell", {
            gain = 1.0,
            pitch = 1.0,
        }, true)
    end
	for _, player in pairs(minetest.get_connected_players()) do
		local time_str = string.format("%dm %ds remaining for the current task", math.floor(time_left / 60), math.floor(time_left % 60))
		if not hud:exists(player, "task_timer") then
			hud:add(player, "task_timer", {
				hud_elem_type = "text",
				position = {x = 0.5, y = 0.95},
				offset = {x = 0, y = -42},
				text = time_str,
				color = 0xFFFFFF,
			})
		else
			hud:change(player, "task_timer", {
				text = time_str
			})
		end
	end
	timer = minetest.after(1, timer_func, time_left - 1)
end

function task_timer.finish()
	if timer == nil then return end
	timer:cancel()
	timer = nil
	hud:remove_all()
end

-- Define the Manage Players formspec
local DASHBOARD_HEADER = "formspec_version[5]size[13,11]"

local function get_player_list_formspec(player, context)
	if not check_perm(player) then
		return "label[0,0;" .. FS"Access denied" .. "]"
	end
	
	if context.selected_student and not minetest.get_player_by_name(context.selected_student) then
		context.selected_student = nil
	end

	local function button(def)
		local x = assert(def.x)
		local y = assert(def.y)
		local w = assert(def.w)
		local h = assert(def.h)
		local name = assert(def.name)
		local text = assert(def.text)
		local state = def.state
		local tooltip = def.tooltip
		local bgcolor = "#222"

		-- Map different state values
		if state == true or state == nil then
			state = "active"
		elseif state == false then
			state = "disabled"
		elseif state == "selected" then
			state = "disabled"
			bgcolor = "#53ac56"
		end

		-- Generate FS code
		local fs
		if state == "active" then
			fs = {
				("button[%f,%f;%f,%f;%s;%s]"):format(x, y, w, h, name, text)
			}
		elseif state == "disabled" then
			name = "disabled_" .. name

			fs = {
				"container[", tostring(x), ",", tostring(y), "]",

				"box[0,0;", tostring(w), ",", tostring(h), ";", bgcolor, "]",

				"style[", name, ";border=false]",
				"button[0,0;", tostring(w), ",", tostring(h), ";", name, ";", text, "]",

				"container_end[]",
			}
		else
			error("Unknown state: " .. state)
		end

		if tooltip then
			fs[#fs + 1] = ("tooltip[%s;%s]"):format(name, tooltip)
		end

		return table.concat(fs, "")
	end

	local fs = {
		"container[0.3,0.3]",
		"tablecolumns[color;text",
	}

	context.select_toggle = context.select_toggle or "all"

	for i, col in pairs(infos) do
		fs[#fs + 1] = ";color;text,align=center"
		if i == 1 then
			fs[#fs + 1] = ",padding=2"
		end
	end
	fs[#fs + 1] = "]"

	do
		fs[#fs + 1] = "tabheader[0,0;6.7,0.8;group;"
		fs[#fs + 1] = FS"All"
		local selected_group_idx = 1
		local i = 2
		for name, group in pairs(minetest_classroom.get_all_groups()) do
			fs[#fs + 1] = ","
			fs[#fs + 1] = minetest.formspec_escape(name)
			if context.groupname and name == context.groupname then
				selected_group_idx = i
			end
			i = i + 1
		end
		fs[#fs + 1] = ";"
		fs[#fs + 1] = tostring(selected_group_idx)
		fs[#fs + 1] = ";false;true]"
	end
	fs[#fs + 1] = "table[0,0;6.7,10.5;students;,Name"
	for _, col in pairs(infos) do
		fs[#fs + 1] = ",," .. col.title
	end

	local students = get_group(context)
	local selection_id = ""
	context.students = table.copy(students)
	for i, student in pairs(students) do
		fs[#fs + 1] = ",,"
		fs[#fs + 1] = minetest.formspec_escape(student)

		if student == context.selected_student then
			selection_id = tostring(i + 1)
		end

		for _, col in pairs(infos) do
			local color, value
			if col.type == "priv" then
				local has_priv = minetest.check_player_privs(student, col.privs)
				color = has_priv and "green" or "red"
				value = has_priv and FS"Yes" or FS"No"
			end

			fs[#fs + 1] = ","
			fs[#fs + 1] = color
			fs[#fs + 1] = ","
			fs[#fs + 1] = minetest.formspec_escape(value)
		end
	end

	fs[#fs + 1] = ";"
	fs[#fs + 1] = selection_id
	fs[#fs + 1] = "]"
	fs[#fs + 1] = "container_end[]"
	
	-- New Group button
	do
		local btn = {
			x = 7.3, y = 0.3,
			w = 2.5, h = 0.8,
			name = "new_group",
			text = FS"New Group",
		}

		fs[#fs + 1] = button(btn)
	end

	-- Edit Group button
	do
		local btn = {
			x = 10, y = 0.3,
			w = 2.5, h = 0.8,
			name = "edit_group",
			text = FS"Edit Group",
			state = context.groupname ~= nil,
			tooltip = not context.groupname and FS"Please select a group first",
		}

		fs[#fs + 1] = button(btn)
	end
	
	-- Apply action to:
	fs[#fs + 1] = "label[7.3,1.6;"
	fs[#fs + 1] = FS"Apply action to:"
	fs[#fs + 1] = "]"
	
	-- Select All button
	do
		local btn = {
			x = 7.3, y = 2,
			w = 1, h = 0.8,
			name = "select_all",
			text = FS"All",
			state = context.select_toggle == "all" and "selected" or "active",
		}

		fs[#fs + 1] = button(btn)
	end

	-- Select Group button
	do
		local btn = {
			x = 8.5, y = 2,
			w = 1.4, h = 0.8,
			name = "select_group",
			text = FS"Group",
		}

		if not context.groupname then
			btn.state = "disabled"
			btn.tooltip = FS"Please select a group first"
		elseif context.select_toggle == "group" then
			btn.state = "selected"
		else
			btn.state = "active"
		end

		fs[#fs + 1] = button(btn)
	end

	-- Select Selected button
	do
		local btn = {
			x = 10, y = 2,
			w = 1.8, h = 0.8,
			name = "select_selected",
			text = FS"Selected",
		}

		if not context.selected_student then
			btn.state = "disabled"
			btn.tooltip = FS"Please select a student first"
		elseif context.select_toggle == "selected" then
			btn.state = "selected"
		else
			btn.state = "active"
		end

		fs[#fs + 1] = button(btn)
	end
	
	fs[#fs + 1] = "label[7.3,3.5;"
	fs[#fs + 1] = FS"Actions:"
	fs[#fs + 1] = "]"
	
	-- Action buttons
	fs[#fs + 1] = "button[7.3,4;2.5,0.8;look;Look]"
	fs[#fs + 1] = "button[10,4;2.5,0.8;bring;Bring]"
	fs[#fs + 1] = "button[7.3,5;2.5,0.8;freeze;Freeze]"
	fs[#fs + 1] = "button[10,5;2.5,0.8;unfreeze;Unfreeze]"
	fs[#fs + 1] = "button[7.3,6;2.5,0.8;dig;Dig]"
	fs[#fs + 1] = "button[10,6;2.5,0.8;nodig;No Dig]"
	fs[#fs + 1] = "button[7.3,7;2.5,0.8;mute;Mute]"
	fs[#fs + 1] = "button[10,7;2.5,0.8;unmute;Unmute]"
	fs[#fs + 1] = "button[7.3,8;2.5,0.8;fly;Fly]"
	fs[#fs + 1] = "button[10,8;2.5,0.8;nofly;No Fly]"
	fs[#fs + 1] = "button[7.3,9;2.5,0.8;kick;Kick]"
	fs[#fs + 1] = "button[10,9;2.5,0.8;ban;Ban]"
	fs[#fs + 1] = "button[7.3,10;2.5,0.8;mesage;Message]"
	fs[#fs + 1] = "button[10,10;2.5,0.8;managebans;Manage Bans]"
	
	return table.concat(fs, "")
end

local function handle_results(player, context, fields)
	if not check_perm(player) then
		return false
	end

	if fields.students then
		local evt = minetest.explode_table_event(fields.students)
		local i = (evt.row or 0) - 1
		if evt.type == "CHG" and i >= 1  and i <= #context.students then
			context.selected_student = context.students[i]
			return true
		end
	end

	if fields.group then
		if fields.group == "1" then
			context.groupname = nil
		else
			local i = 2
			for name, _ in pairs(minetest_classroom.get_all_groups()) do
				if i == tonumber(fields.group) then
					context.groupname = name
					break
				end
				i = i + 1
			end
		end
		return true
	end

	if fields.select_all then
		context.select_toggle = "all"
		return true
	elseif fields.select_group then
		context.select_toggle = "group"
		return true
	elseif fields.select_selected then
		context.select_toggle = "selected"
		return true
	end

	if fields.teleport and context.selected_student then
		local student = minetest.get_player_by_name(context.selected_student)
		if student then
			player:set_pos(student:get_pos())
			return false
		else
			context.selected_student = nil
			return true
		end
	end

	if fields.new_group then
		minetest_classroom.show_new_group(player)
		return false
	end

	if fields.edit_group and context.groupname then
		minetest_classroom.show_edit_group(player, context.groupname)
		return false
	end

	for _, action in pairs(minetest_classroom.get_actions()) do
		if fields["action_" .. action.name] then
			local selector
			if context.select_toggle == "all" then
				selector = "*"
			elseif context.select_toggle == "group" then
				selector = "group:" .. context.groupname
			elseif context.select_toggle == "selected" then
				selector = "user:" .. context.selected_student
			else
				error("Unknown selector")
			end

			minetest_classroom.run_action(action.name, player, selector)
			return true
		end
	end

end

local _contexts = {}
local function show_players(player)
	if check_perm(player) then
		local pname = player:get_player_name()
		local context = _contexts[pname] or {}
		_contexts[pname] = context
		minetest.show_formspec(pname, "mc_teacher:players", DASHBOARD_HEADER .. get_player_list_formspec(player, context))
		return true
	end
end

-- Define the Manage Lessons formspec
local mc_teacher_lessons = 
		"formspec_version[5]"..
		""

local function show_lessons(player)
	if check_perm(player) then
		local pname = player:get_player_name()
		minetest.show_formspec(pname, "mc_teacher:lessons", mc_teacher_lessons)
		return true
	end
end

-- Define the Manage Classrooms formspec
local function show_classrooms(player)
	if check_perm(player) then
		mc_teacher_classrooms = 
			"formspec_version[5]"..
			"size[14,14]"..
			"label[0.4,0.8;Your Classrooms]"..
			"button[0.375,6.5;4,0.8;join;Join Selected Classroom]"..
			"button[0.375,7.5;4,0.8;delete;Delete Selected Classroom]"
			
		-- Get the stored classrooms for the teacher	
		pmeta = player:get_meta()
		
		-- reset
		-- pmeta:set_string("classrooms",nil)
		-- minetest_classroom.classrooms:set_string("classrooms",nil)
		
		pdata = minetest.deserialize(pmeta:get_string("classrooms"))
		
		if pdata == nil then
			-- No classrooms stored, so return an empty list element
			mc_teacher_classrooms = 
			mc_teacher_classrooms.. 
			"textlist[0.4,1.1;13.2,5.2;classroomlist;No Courses Found;1;false]"
		else
			mc_teacher_classrooms = mc_teacher_classrooms .. "textlist[0.4,1.1;13.2,5.2;classroomlist;"
			-- Some classrooms were found, so iterate the list
			pcc = pdata.course_code
			psn = pdata.section_number
			psy = pdata.start_year
			psm = pdata.start_month
			psd = pdata.start_day
			pey = pdata.end_year
			pem = pdata.end_month
			ped = pdata.end_day
			pac = pdata.access_code
			map = pdata.classroom_map
			for i in pairs(pcc) do
				mc_teacher_classrooms = mc_teacher_classrooms..pcc[i].." "..psn[i].." "..map[i].." Expires "..pem[i].." "..ped[i].." "..pey[i].." Access Code = "..pac[i]..","
			end
			mc_teacher_classrooms = mc_teacher_classrooms .. ";1;false]"
		end
		mc_teacher_classrooms = mc_teacher_classrooms ..
			"field[7.1,7;2.1,0.8;coursecode;Course Code;CONS340]"..
			"field[9.4,7;1.2,0.8;sectionnumber;Section Number;101]"..
			"label[7.1,8.35;Course START Date and Time]"..
			"dropdown[8.1,8.6;2.3,0.8;startmonth;January,February,March,April,May,June,July,August,September,October,November,December;9;false]"..
			"dropdown[7.1,8.6;0.9,0.8;startday;1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31;1;false]"..
			"dropdown[10.5,8.6;1.4,0.8;startyear;2022,2023;1;false]"..
			"dropdown[12.1,8.6;1.5,0.8;starthour;00:00,01:00,02:00,03:00,04:00,05:00,06:00,07:00,08:00,09:00,10:00,11:00,12:00,13:00,14:00,15:00,16:00,17:00,18:00,19:00,20:00,21:00,22:00,23:00;9;false]"..
			"label[7.1,10;Course END Date and Time]"..
			"dropdown[8.1,10.25;2.3,0.8;endmonth;January,February,March,April,May,June,July,August,September,October,November,December;12;false]"..
			"dropdown[7.1,10.25;0.9,0.8;endday;1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31;1;false]"..
			"dropdown[10.5,10.25;1.4,0.8;endyear;2022,2023;1;false]"..
			"dropdown[12.1,10.25;1.5,0.8;endhour;00:00,01:00,02:00,03:00,04:00,05:00,06:00,07:00,08:00,09:00,10:00,11:00,12:00,13:00,14:00,15:00,16:00,17:00,18:00,19:00,20:00,21:00,22:00,23:00;21;false]"..
			"dropdown[12.1,10.25;1.5,0.8;endhour;00:00,01:00,02:00,03:00,04:00,05:00,06:00,07:00,08:00,09:00,10:00,11:00,12:00,13:00,14:00,15:00,16:00,17:00,18:00,19:00,20:00,21:00,22:00,23:00;21;false]"..
			"label[7.1,11.75;Map Selection]"..
			
			-- TODO: Dynamically populate the map list
			"dropdown[7.1,12;6.5,0.8;map;vancouver_osm,MKRF512_all,MKRF512_slope,MKRF512_aspect,MKRF512_dtm;1;false]"..
			"button[9.625,13;4,0.8;submit;Create New Classroom]"..
			"button[0.375,13;2,0.8;back;Back]"..
			"button[2.575,13;2,0.8;deleteall;Delete All]"
			
		local pname = player:get_player_name()
		minetest.show_formspec(pname, "mc_teacher:classrooms", mc_teacher_classrooms)
		return true
	end
end

-- Define the Teacher Mail formspec
local function get_reports_formspec(reports)
	local mc_teacher_mail = 
			"formspec_version[5]"..
			"size[15,10]"..
			"label[6.3,0.5;Reports Received]"..
			"textlist[0.3,1;14.4,8;;"
	-- Add the reports
	local reports_table = minetest_classroom.reports:to_table()["fields"]
	for k, v in pairs(reports_table) do
		mc_teacher_mail = mc_teacher_mail .. k .. " " .. v .. ","
	end
	local mc_teacher_mail = mc_teacher_mail..
			";1;false]"..
			"button[0.3,9.1;2,0.8;back;Back]"..
			"button[2.5,9.1;2.5,0.8;deleteall;Delete All]"
	return mc_teacher_mail
end

local function show_mail(player)
	if check_perm(player) then
		local pname = player:get_player_name()
		minetest.show_formspec(pname, "mc_teacher:mail", get_reports_formspec(minetest_classroom.reports))
		return true
	end
end

local function get_species_formspec()
	local species = table.concat(magnify.get_all_registered_species(), ",")
	local formtable = {
		"formspec_version[5]",
		"size[12,8]",
		"box[0.4,0.4;11.2,1;#378738]", -- #378742
		"label[3.9,0.9;Plant Species Compendium]",
		"textlist[0.4,1.6;11.2,4.8;species_list;", species, ";", context.species_selected or 1, ";false]",
		"button[0.4,6.6;3.6,1;condensed_view;Standard View]",
		"button[4.2,6.6;3.6,1;expanded_view;Technical View]",
		"button[8,6.6;3.6,1;back;Back]"
	}
	return table.concat(formtable, "")
end

local function get_condensed_species_formspec(info)
	-- add condensed table here
	local formtable = {  
    	"formspec_version[5]",
		"size[18.2,7.7]",
		"box[0.4,0.4;11.6,1.6;", minetest.formspec_escape(info.status_col or "#9192a3"), "]",
		"label[0.5,0.7;", minetest.formspec_escape(info.sci_name or "N/A"), "]",
		"label[0.5,1.2;", minetest.formspec_escape((info.com_name and "Common name: "..info.com_name) or "Common name unknown"), "]",
    	"label[0.5,1.7;", minetest.formspec_escape((info.fam_name and "Family: "..info.fam_name) or "Family unknown"), "]",
		"image[12.4,0.4;5.4,5.4;", minetest.formspec_escape(info.texture or "test.png"), "]",
    
		"label[0.4,2.5;-]",
    	"label[0.4,3;-]",
		"label[0.4,3.5;-]",
    	"label[0.4,4;-]",
		"label[0.7,2.5;", minetest.formspec_escape(info.cons_status or "Conservation status unknown"), "]",
    	"label[0.7,3;", minetest.formspec_escape((info.region and "Native to "..info.region) or "Native region unknown"), "]",
		"label[0.7,3.5;", minetest.formspec_escape(info.height or "Height unknown"), "]",
		"label[0.7,4;", minetest.formspec_escape(info.bloom or "Bloom pattern unknown"), "]",
		
    	"textarea[0.35,4.45;11.5,1.3;;;", minetest.formspec_escape(info.more_info or ""), "]",
    	"label[0.4,6.25;", minetest.formspec_escape((info.img_copyright and "Image © "..info.img_copyright) or (info.img_credit and "Image courtesy of "..info.img_credit) or ""), "]",
		"label[0.4,6.75;", minetest.formspec_escape((info.external_link and "You can find more information at:") or ""), "]",
    	"textarea[0.35,6.9;11.6,0.6;;;", minetest.formspec_escape(info.external_link or ""), "]",
		
    	"button[12.4,6.1;5.4,1.2;back;Back]"
    }
	return table.concat(formtable, "")
end

local function get_expanded_species_formspec(info, nodes, ref)
	-- add expanded table here
	local formtable = {    
    	"formspec_version[5]",
		"size[14,8.2]",
		"box[0.4,0.4;13.2,1;#9192a3]",
		"label[5.4,0.9;Technical Information]",
		"label[0.4,1.9;", info.com_name or info.sci_name or "Unknown", " (", ref, ")]",
		"image[8.8,1.7;4.8,4.8;", info.texture or "test.png", "]",
		"textlist[0.4,2.8;8.1,3.7;associated_blocks;", table.concat(nodes, ","), ";1;false]",
		"label[0.4,2.5;Associated nodes:]",
		"button[4.8,6.8;4.4,1;back;Back]"
	}
	return table.concat(formtable, "")
end

local function show_species(player)
	if check_perm(player) then
		if not context.species_selected then
			context.species_selected = 1
		end
		local pname = player:get_player_name()
		minetest.show_formspec(pname, "mc_teacher:species_menu", get_species_formspec())
		return true
	end
end

local function get_species_ref(index)
  	local list = magnify.get_all_registered_species()
	local elem = list[tonumber(index)]
	local ref_num_split = string.split(elem, ":") -- "###num:rest"
  	local ref_str = ref_num_split[1]
	local ref_num = string.sub(ref_str, 4) -- removes "###" from "###num"
	
	return "ref_"..ref_num
end

-- TODO: add Change Server Rules to the menu

-- Processing the form from the menu
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if string.sub(formname, 1, 10) ~= "mc_teacher" or not check_perm(player) then
		return false
	end
	
	local wait = os.clock()
	while os.clock() - wait < 0.05 do end --popups don't work without this
	
	local pname = player:get_player_name()
	
	-- Menu
	if formname == "mc_teacher:menu" then 
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
		elseif fields.tasks then
			show_tasks(player)
		elseif fields.lessons then
			show_lessons(player)
		elseif fields.classrooms then
			show_classrooms(player)
		elseif fields.players then
			show_players(player)
		elseif fields.species then
			show_species(player)
		elseif fields.mail then
			show_mail(player)
		end
	end
	
	if formname == "mc_teacher:players" then
		local context = _contexts[player:get_player_name()]
		if not context then
			return false
		end

		local ret = handle_results(player, context, fields)
		if ret then
			show_players(player)
		end
		return ret
	end
	
	if formname == "mc_teacher:tasks" then
		if fields.back then
			show_teacher_menu(player)
		elseif fields.task and fields.instructions then
			-- Build the formspec - this must be a global variable to be accessed by mc_student
			minetest_classroom.currenttask =
					"formspec_version[5]"..
					"size[10,12]"..
					"style_type[label;font_size=*1.5]"..
					"label[0.375,0.75;"..fields.task.."]"..
					"style[textarea;textcolor=black]"..
					"textarea[0.375,1.5;9.25,8;instructs;;"..fields.instructions.."]"..
					"style_type[label;font_size=*1]"..
					"label[0.375,9.75;You can view these task instructions again from your notebook.]"..
					"button_exit[0.375,10.5;2,0.8;ok;OK]"
			-- Send the task to everyone
			for _, player in pairs(minetest.get_connected_players()) do
				minetest.show_formspec(player:get_player_name(), "task:instructions", minetest_classroom.currenttask)
			end
			-- Kill any existing task timer
			task_timer.finish()
			if fields.timer ~= "" then
				if tonumber(fields.timer) > 0 then timer = minetest.after(1, timer_func, tonumber(fields.timer)) end
			end
		else
			minetest.chat_send_player(player:get_player_name(),minetest.colorize("#FF0000","Error: Did not receive complete task or instructions. The task was not sent to players."))
		end
	end
	
	if formname == "mc_teacher:mail" then
		if fields.deleteall then
			local reports_table = minetest_classroom.reports:to_table()["fields"]
			for k, _ in pairs(reports_table) do
				minetest_classroom.reports:set_string(k, nil)
			end
			show_mail(player)
		end
		
		if fields.back then
			show_teacher_menu(player)
		end
	end
	
	if formname == "mc_teacher:classrooms" then
		if fields.submit then
			-- validate everything and prepare for storage
			if string.len(fields.coursecode) ~= 7 then
				minetest.chat_send_player(pname,pname..": Course code is not valid. Expected format ABCD123. Please try again.")
				return
			end
			
			if string.len(fields.sectionnumber) ~= 3 then
				minetest.chat_send_player(pname,pname..": Section number is not valid. Expected format 123. Please try again.")
				return
			end
			
			-- validate that the end date is after the start date
			if tonumber(fields.endyear) == tonumber(fields.startyear) and (months[fields.endmonth] == months[fields.startmonth]) and tonumber(fields.endday) >= tonumber(fields.startday) and tonumber(string.sub(fields.endhour, 1, 2)) >= tonumber(string.sub(fields.starthour, 1, 2)) then
				minetest.chat_send_player(pname,pname..": Start and end dates and times must be different. Please check and try again.")
				return
			end
			
			if tonumber(fields.endyear) >= tonumber(fields.startyear) then
				if (months[fields.endmonth] >= months[fields.startmonth]) or (tonumber(fields.endyear) > tonumber(fields.startyear)) then
					if tonumber(fields.endday) >= tonumber(fields.startday) then
						if tonumber(string.sub(fields.endhour, 1, 2)) >= tonumber(string.sub(fields.starthour, 1, 2)) then
							-- Everything checks out so proceed to encode the data to modstorage
							record_classroom(player,fields.coursecode,fields.sectionnumber,fields.startyear,fields.startmonth,fields.startday,fields.endyear,fields.endmonth,fields.endday,fields.map)
						else
							minetest.chat_send_player(pname,pname..": Start hour must come before the end hour, day, month, and year. Please check and try again.")
						end
					else
						minetest.chat_send_player(pname,pname..": Start day must come before the end day, month, and year. Please try again.")
					end
				else
					minetest.chat_send_player(pname,pname..": Start month must come before the end month and year. Please check and try again.")
				end
			else 
				minetest.chat_send_player(pname,pname..": Start year must come before the end year. Please check and try again.")
			end
			
		elseif fields.classroomlist then
			local event = minetest.explode_textlist_event(fields.classroomlist)
			if event.type == "CHG" then -- "CHG" = something is selected in the list
				context.selected = event.index
			end
		elseif fields.join then
			pmeta = player:get_meta()
			pdata = minetest.deserialize(pmeta:get_string("classrooms"))
			if context.selected then
				mdata = minetest.deserialize(minetest_classroom.classrooms:get_string("classrooms"))
				if mdata.spawn_pos[context.selected] then
					player:set_pos(mdata.spawn_pos[context.selected])
				else
					minetest.chat_send_player(pname,pname..": Error receiving the spawn coordinates. Try regenerating the classroom.")
				end
			else
				minetest.chat_send_player(pname,pname..": Please click on a classroom in the list to join.")
			end
		elseif fields.back then
			show_teacher_menu(player)
		elseif fields.delete then
		-- TO DO: currently, this function only deletes the symbolic link to the classroom in the palyer/mod metadata. need to also remove the physical world.
			-- Update player metadata
			if context.selected then
				pmeta = player:get_meta()
				pdata = minetest.deserialize(pmeta:get_string("classrooms"))
				-- Update modstorage first
				mdata = minetest.deserialize(minetest_classroom.classrooms:get_string("classrooms"))
				loc = check_access_code(pdata.access_code[context.selected],mdata.access_code)
				mdata.course_code[loc] = nil
				mdata.section_number[loc] = nil
				mdata.start_year[loc] = nil
				mdata.start_month[loc] = nil
				mdata.start_day[loc] = nil
				mdata.end_year[loc] = nil
				mdata.end_month[loc] = nil
				mdata.end_day[loc] = nil
				mdata.classroom_map[loc] = nil
				mdata.access_code[loc] = nil
				mdata.spawn_pos[loc] = nil
				minetest_classroom.classrooms:set_string("classrooms",minetest.serialize(mdata
				))
				
				-- Update player metadata
				pdata.course_code[context.selected] = nil
				pdata.section_number[context.selected] = nil
				pdata.start_year[context.selected] = nil
				pdata.start_month[context.selected] = nil
				pdata.start_day[context.selected] = nil
				pdata.end_year[context.selected] = nil
				pdata.end_month[context.selected] = nil
				pdata.end_day[context.selected] = nil
				pdata.classroom_map[context.selected] = nil
				pdata.access_code[context.selected] = nil
				pdata.spawn_pos[context.selected] = nil
				pmeta:set_string("classrooms",minetest.serialize(pdata
				))
				show_classrooms(player)
			else
				minetest.chat_send_player(pname,pname..": Please click on a classroom in the list to delete.")
			end
		-- TODO: eventually delete this button, only useful for testing
		elseif fields.deleteall then
			pmeta:set_string("classrooms", nil)
			minetest_classroom.classrooms:set_string("classrooms", nil)
			show_classrooms(player)
		else -- escape without input
			return
		end
	end

	if formname == "mc_teacher:species_menu" then
		if fields.back then
		  	show_teacher_menu(player)
		elseif fields.species_list then
        	local event = minetest.explode_textlist_event(fields.species_list)
        	if event.type == "CHG" then
        		context.species_selected = event.index
        	end
		elseif fields.condensed_view or fields.expanded_view then
			if context.species_selected then
      			local ref = get_species_ref(context.species_selected)
          		local full_info = magnify.get_species_from_ref(ref)
          
				if full_info ~= nil then
          			if fields.condensed_view then -- condensed
						minetest.show_formspec(pname, "mc_teacher:species_condensed", get_condensed_species_formspec(full_info.data))
            		else -- expanded
            			minetest.show_formspec(pname, "mc_teacher:species_expanded", get_expanded_species_formspec(full_info.data, full_info.nodes, ref))
            		end
				else
					minetest.chat_send_player(pname, "An entry for this species exists, but could not be found in the plant database.\nPlease check your server's plant database files to ensure all plants were registered properly.")
				end	
        	end
		end
	end
  
  	if formname == "mc_teacher:species_condensed" then
    	-- handle buttons (TBD)
      	if fields.back then 
        	show_species(player)
        end
    end
    
    if formname == "mc_teacher:species_expanded" then
      -- handle buttons (TBD)
      	if fields.back then
          	show_species(player)
        end
    end
end)

function record_classroom(player,cc,sn,sy,sm,sd,ey,em,ed,map)
	if check_perm(player) then
		local pname = player:get_player_name()
		pmeta = player:get_meta()
		
		-- Focus on modstorage because it is persistent and not dependent on player being online
		temp = minetest.deserialize(minetest_classroom.classrooms:get_string("classrooms"))

		-- Generate an access code
		math.randomseed(os.time())
		access_num = tostring(math.floor(math.random()*100000))

		-- Get the last classroom map position
		last_map_pos = minetest.deserialize(minetest_classroom.classrooms:get_string("last_map_pos"))
		if last_map_pos == nil then
			-- this value has not yet been initialized, so use {x=2000, z=0, y=3500} as a placeholder for the corner of the UBC campus landing map
			last_map_pos = {x=2000, y=0, z=3500,}
			new_map_pos = last_map_pos
			-- Send to modstorage
			minetest_classroom.classrooms:set_string("last_map_pos",minetest.serialize(new_map_pos))
		else
			-- Update the last map pos by adding 1024 to the x coordinate
			new_map_pos = last_map_pos
			new_map_pos.x = last_map_pos.x + 1024
			
			-- Update last map pos in modstorage
			minetest_classroom.classrooms:set_string("last_map_pos",minetest.serialize(new_map_pos))
		end
		
		-- Place the map
		place_map(player,map,new_map_pos)
		
		-- Retrieve spawn position from map metadata
		local mmeta = Settings(minetest.get_modpath("mc_teacher").."/maps/"..map..".conf")
		local spawn_pos_x = tonumber(mmeta:get("spawn_pos_x"))+new_map_pos.x
		local spawn_pos_y = tonumber(mmeta:get("spawn_pos_y"))
		local spawn_pos_z = tonumber(mmeta:get("spawn_pos_z"))+new_map_pos.z
		local spawn_pos = {
			x = spawn_pos_x,
			y = spawn_pos_y,
			z = spawn_pos_z,
		}
		
		if temp == nil then
			-- Build the new classroom table entry
			classroomdata = {
				course_code = { cc },
				section_number = { sn },
				start_year = { sy },
				start_month = { sm },
				start_day = { sd },
				end_year = { ey },
				end_month = { em },
				end_day = { ed },
				classroom_map = { map },
				access_code = { access_num },
				spawn_pos = { spawn_pos },
			}
		else
			table.insert(temp.course_code, cc)
			table.insert(temp.section_number, sn)
			table.insert(temp.start_year, sy)
			table.insert(temp.start_month, sm)
			table.insert(temp.start_day, sd)
			table.insert(temp.end_year, ey)
			table.insert(temp.end_month, em)
			table.insert(temp.end_day, ed)
			table.insert(temp.classroom_map, map)
			table.insert(temp.access_code, access_num)
			table.insert(temp.spawn_pos, spawn_pos)
			classroomdata = {
				course_code = temp.course_code,
				section_number = temp.section_number,
				start_year = temp.start_year,
				start_month = temp.start_month,
				start_day = temp.start_day,
				end_year = temp.end_year,
				end_month = temp.end_month,
				end_day = temp.end_day,
				classroom_map = temp.classroom_map,
				access_code = temp.access_code,
				spawn_pos = temp.spawn_pos,
			}
		end
		
		-- Send to modstorage
		minetest_classroom.classrooms:set_string("classrooms",minetest.serialize(classroomdata))
		
		-- Send to teacher player's metadata
		pmeta:set_string("classrooms",minetest.serialize(classroomdata))
		minetest.chat_send_player(pname,pname..": Your course was successfully recorded.")
		
		-- Send player to spawn pos of classroom map
		player:set_pos(spawn_pos)
		
		-- Update the formspec
		show_classrooms(player)
		temp = nil
	end
end

-- Month look-up table for classroom scheduling
months = {
	January = 1,
	February = 2,
	March = 3,
	April = 4,
	May = 5,
	June = 6,
	July = 7,
	August = 8,
	September = 9,
	October = 10,
	November = 11,
	December = 12,
}

function place_map(player,map_name,pos)
	local pname = player:get_player_name()
	if check_perm(player) then
		minetest.place_schematic(pos, minetest.get_modpath("mc_teacher").."/maps/"..map_name..".mts", 0, nil, true)
	else
		minetest.chat_send_player(pname,pname..": You do not have the teacher privilege to create a new map. Check with the server administrator.")
	end
end

-- The controller for accessing the teacher actions
minetest.register_tool("mc_teacher:controller" , {
	description = "Controller for teachers",
	inventory_image = "controller.png",
	-- Left-click the tool activates the teacher menu
	on_use = function (itemstack, user, pointed_thing)
        local pname = user:get_player_name()
		-- Check for teacher privileges
		if check_perm(user) then
			show_teacher_menu(user)
		end
	end,
	-- Destroy the controller on_drop so that students cannot pick it up (i.e, disallow dropping without first revoking teacher)
	on_drop = function (itemstack, dropper, pos)
		minetest.set_node(pos, {name="air"})
	end,
})

-- Give the controller to any player who joins with teacher privileges or take away the controller if they are not teacher
minetest.register_on_joinplayer(function(player)
	local inv = player:get_inventory()
	if inv:contains_item("main", ItemStack("mc_teacher:controller")) then
		-- Player has the controller
		if check_perm(player) then
			-- The player should have the controller
			return
		else
			-- The player should not have the controller
			player:get_inventory():remove_item('main', 'mc_teacher:controller')
		end
	else
		-- Player does not have the controller
		if check_perm(player) then
			-- The player should have the controller
			player:get_inventory():add_item('main', 'mc_teacher:controller')
		else
			-- The player should not have the controller
			return
		end
	end
end)
