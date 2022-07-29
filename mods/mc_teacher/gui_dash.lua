local S = minetest_classroom.S
local FS = minetest_classroom.FS
context = {}
local infos = {
    {
        title = S "Mute?",
        type = "priv",
        privs = { shout = true },
    },
    {
        title = S "Fly?",
        type = "priv",
        privs = { fly = true },
    },
    {
        title = S "Freeze?",
        type = "priv",
        privs = { fast = true },
    },
    {
        title = S "Dig?",
        type = "priv",
        privs = { interact = true },
    },
}
local tool_name = "mc_teacher:controller"
local priv_table = { teacher = true }

local function get_group(context)
    if context and context.groupname then
        if (context.groupname == "Realm") then
            return minetest_classroom.get_realm_students(context.realm)
        else
            return minetest_classroom.get_group_students(context.groupname)
        end

    else
        return minetest_classroom.get_students()
    end
end

-- Label the teacher in red
minetest.register_on_joinplayer(function(player)
    if mc_helpers.checkPrivs(player, priv_table) then
        player:set_nametag_attributes({ color = { r = 255, g = 0, b = 0 } })
    end
end)

-- Define an initial formspec that will redirect to different formspecs depending on what the teacher wants to do
local mc_teacher_menu = {
    "formspec_version[5]",
    "size[10,9]",
    "label[3.2,0.7;What do you want to do?]",
    "button[1,1.6;3.8,1.3;spawn;Go to UBC]",
    "button[5.2,1.6;3.8,1.3;tasks;Manage Tasks]",
    "button[1,3.3;3.8,1.3;lessons;Manage Lessons]",
    "button[5.2,3.3;3.8,1.3;players;Manage Players]",
    "button[1,5;3.8,1.3;classrooms;Manage Classrooms]",
    "button[5.2,5;3.8,1.3;rules;Manage Server Rules]",
    "button[1,6.7;3.8,1.3;mail;Teacher Mail]",
    "button_exit[5.2,6.7;3.8,1.3;exit;Exit]"
}

local function show_teacher_menu(player)
    if mc_helpers.checkPrivs(player, priv_table) then
        local pname = player:get_player_name()
        minetest.show_formspec(pname, "mc_teacher:menu", table.concat(mc_teacher_menu, ""))
        return true
    end
end

-- Define the Manage Tasks formspec (teacher-view)
local mc_teacher_tasks = {
    "formspec_version[5]",
    "size[10,13]",
    "field[0.375,0.75;9.25,0.8;task;Enter task below;]",
    "textarea[0.375,2.5;9.25,7;instructions;Enter instructions below;]",
    "field[0.375,10.5;9.25,0.8;timer;Enter timer for task in seconds (0 or blank = no timer);]",
    "button[0.375,11.5;2,0.8;back;Back]",
    "button_exit[2.575,11.5;2,0.8;submit;Submit]"
}

local function show_tasks(player)
    if mc_helpers.checkPrivs(player, priv_table) then
        local pname = player:get_player_name()
        minetest.show_formspec(pname, "mc_teacher:tasks", table.concat(mc_teacher_tasks, ""))
        return true
    end
end

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
                position = { x = 0.5, y = 0.95 },
                offset = { x = 0, y = -42 },
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
    if timer == nil then
        return
    end
    timer:cancel()
    timer = nil
    hud:remove_all()
end

-- Define the Manage Players formspec
local DASHBOARD_HEADER = "formspec_version[5]size[13,11]"

local function get_player_list_formspec(player, context)
    if not mc_helpers.checkPrivs(player, priv_table) then
        return "label[0,0;" .. FS "Access denied" .. "]"
    end

    if context.selected_student and not minetest.get_player_by_name(context.selected_student) then
        context.selected_student = nil
    end

    context.realm = Realm.GetRealmFromPlayer(player).ID

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

    context.select_toggle = context.select_toggle or "realm"

    for i, col in pairs(infos) do
        fs[#fs + 1] = ";color;text,align=center"
        if i == 1 then
            fs[#fs + 1] = ",padding=2"
        end
    end
    fs[#fs + 1] = "]"

    do
        fs[#fs + 1] = "tabheader[0,0;6.7,0.8;group;"
        fs[#fs + 1] = FS "All"

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
                value = has_priv and FS "Yes" or FS "No"
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
            text = FS "New Group",
        }

        fs[#fs + 1] = button(btn)
    end

    -- Edit Group button
    do
        local btn = {
            x = 10, y = 0.3,
            w = 2.5, h = 0.8,
            name = "edit_group",
            text = FS "Edit Group",
            state = context.groupname ~= nil and context.groupname ~= "Realm",
            tooltip = not context.groupname and FS "Please select a group first",
        }

        fs[#fs + 1] = button(btn)
    end

    -- Apply action to:
    fs[#fs + 1] = "label[7.3,1.6;"
    fs[#fs + 1] = FS "Apply action to:"
    fs[#fs + 1] = "]"

    -- Select All button
    do
        local btn = {
            x = 7.3, y = 2,
            w = 1, h = 0.8,
            name = "select_all",
            text = FS "All",
            state = context.select_toggle == "all" and "selected" or "active",
        }

        fs[#fs + 1] = button(btn)
    end

    -- Select Group button
    do
        local btn = {
            x = 8.5, y = 2,
            w = 1, h = 0.8,
            name = "select_group",
            text = FS "Group",
        }

        if (context.groupname == nil or context.groupname == "Realm") then
            btn.state = "disabled"
            btn.tooltip = FS "Please select a group first"
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
            x = 9.7, y = 2,
            w = 1, h = 0.8,
            name = "select_selected",
            text = FS "Selected",
        }

        if not context.selected_student then
            btn.state = "disabled"
            btn.tooltip = FS "Please select a student first"
        elseif context.select_toggle == "selected" then
            btn.state = "selected"
        else
            btn.state = "active"
        end

        fs[#fs + 1] = button(btn)
    end

    -- Select Realm button
    do
        local btn = {
            x = 10.9, y = 2,
            w = 1, h = 0.8,
            name = "select_realm",
            text = FS "Realm",
        }

        if context.select_toggle == "realm" then
            btn.state = "selected"
        else
            btn.state = "active"
        end

        fs[#fs + 1] = button(btn)
    end

    fs[#fs + 1] = "label[7.3,3.5;"
    fs[#fs + 1] = FS "Actions:"
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
    if not mc_helpers.checkPrivs(player, priv_table) then
        return false
    end

    if fields.students then
        local evt = minetest.explode_table_event(fields.students)
        local i = (evt.row or 0) - 1
        if evt.type == "CHG" and i >= 1 and i <= #context.students then
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
    elseif fields.select_realm then
        context.select_toggle = "realm"
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
            elseif context.select_toggle == "realm" then
                selector = "realm:" .. context.realm
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
    if mc_helpers.checkPrivs(player, priv_table) then
        local pname = player:get_player_name()
        local context = _contexts[pname] or {}
        _contexts[pname] = context
        minetest.show_formspec(pname, "mc_teacher:players", DASHBOARD_HEADER .. get_player_list_formspec(player, context))
        return true
    end
end

-- Define the Manage Lessons formspec
-- TODO: incorporate or abandon this feature
local mc_teacher_lessons = "formspec_version[5]"

local function show_lessons(player)
    if mc_helpers.checkPrivs(player, priv_table) then
        local pname = player:get_player_name()
        minetest.show_formspec(pname, "mc_teacher:lessons", mc_teacher_lessons)
        return true
    end
end

-- Define the Manage Classrooms formspec
local function show_classrooms(player)
    if mc_helpers.checkPrivs(player, priv_table) then
        local mc_teacher_classrooms = {
            "formspec_version[5]",
            "size[14,14]",
            "label[0.4,0.8;Your Classrooms]",
            "button[0.375,6.5;4,0.8;join;Join Selected Classroom]",
            "button[0.375,7.5;4,0.8;delete;Delete Selected Classroom]"
        }

        -- Get the stored classrooms for the teacher
        pmeta = player:get_meta()

        -- reset
        -- pmeta:set_string("classrooms",nil)
        -- minetest_classroom.classrooms:set_string("classrooms",nil)

        pdata = minetest.deserialize(pmeta:get_string("classrooms"))

        if pdata == nil then
            -- No classrooms stored, so return an empty list element
            mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "textlist[0.4,1.1;13.2,5.2;classroomlist;No Courses Found;1;false]"
        else
            mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "textlist[0.4,1.1;13.2,5.2;classroomlist;"
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
            rid = pdata.realm_id
            for i in pairs(pcc) do
                mc_teacher_classrooms[#mc_teacher_classrooms + 1] = pcc[i]
                mc_teacher_classrooms[#mc_teacher_classrooms + 1] = " "
                mc_teacher_classrooms[#mc_teacher_classrooms + 1] = psn[i]
                mc_teacher_classrooms[#mc_teacher_classrooms + 1] = " "
                mc_teacher_classrooms[#mc_teacher_classrooms + 1] = map[i]
                mc_teacher_classrooms[#mc_teacher_classrooms + 1] = " Expires "
                mc_teacher_classrooms[#mc_teacher_classrooms + 1] = pem[i]
                mc_teacher_classrooms[#mc_teacher_classrooms + 1] = " "
                mc_teacher_classrooms[#mc_teacher_classrooms + 1] = ped[i]
                mc_teacher_classrooms[#mc_teacher_classrooms + 1] = " "
                mc_teacher_classrooms[#mc_teacher_classrooms + 1] = pey[i]
                mc_teacher_classrooms[#mc_teacher_classrooms + 1] = " Access Code = "
                mc_teacher_classrooms[#mc_teacher_classrooms + 1] = pac[i]
                mc_teacher_classrooms[#mc_teacher_classrooms + 1] = ","
            end
            mc_teacher_classrooms[#mc_teacher_classrooms + 1] = ";1;false]"
        end

        -- TODO: Integrate asynchronous and automatic deletion of realms based on user-entered information below
        mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "field[7.1,7;2.1,0.8;coursecode;Course Code;CONS340]"
        mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "field[9.4,7;1.2,0.8;sectionnumber;Section Number;101]"
        mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "label[7.1,8.35;Course START Date and Time]"
        mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "dropdown[8.1,8.6;2.3,0.8;startmonth;January,February,March,April,May,June,July,August,September,October,November,December;9;false]"
        mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "dropdown[7.1,8.6;0.9,0.8;startday;1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31;1;false]"
        mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "dropdown[10.5,8.6;1.4,0.8;startyear;2022,2023;1;false]"
        mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "dropdown[12.1,8.6;1.5,0.8;starthour;00:00,01:00,02:00,03:00,04:00,05:00,06:00,07:00,08:00,09:00,10:00,11:00,12:00,13:00,14:00,15:00,16:00,17:00,18:00,19:00,20:00,21:00,22:00,23:00;9;false]"
        mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "label[7.1,10;Course END Date and Time]"
        mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "dropdown[8.1,10.25;2.3,0.8;endmonth;January,February,March,April,May,June,July,August,September,October,November,December;12;false]"
        mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "dropdown[7.1,10.25;0.9,0.8;endday;1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31;1;false]"
        mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "dropdown[10.5,10.25;1.4,0.8;endyear;2022,2023;1;false]"
        mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "dropdown[12.1,10.25;1.5,0.8;endhour;00:00,01:00,02:00,03:00,04:00,05:00,06:00,07:00,08:00,09:00,10:00,11:00,12:00,13:00,14:00,15:00,16:00,17:00,18:00,19:00,20:00,21:00,22:00,23:00;21;false]"
        mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "dropdown[12.1,10.25;1.5,0.8;endhour;00:00,01:00,02:00,03:00,04:00,05:00,06:00,07:00,08:00,09:00,10:00,11:00,12:00,13:00,14:00,15:00,16:00,17:00,18:00,19:00,20:00,21:00,22:00,23:00;21;false]"
        mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "label[7.1,11.75;Map Selection]"

        -- TODO: Dynamically populate the realm/schematic list
        mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "dropdown[7.1,12;6.5,0.8;map;vancouver_osm,MKRF512_all,MKRF512_slope,MKRF512_aspect,MKRF512_dtm;1;false]"
        mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "button[9.625,13;4,0.8;submit;Create New Classroom]"
        mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "button[0.375,13;2,0.8;back;Back]"
        mc_teacher_classrooms[#mc_teacher_classrooms + 1] = "button[2.575,13;2,0.8;deleteall;Delete All]"

        local pname = player:get_player_name()
        minetest.show_formspec(pname, "mc_teacher:classrooms", table.concat(mc_teacher_classrooms, ""))
        return true
    end
end

-- Define the Teacher Mail formspec
local function get_reports_formspec(reports)
    local mc_teacher_mail = {
        "formspec_version[5]",
        "size[15,10]",
        "label[6.3,0.5;Reports Received]",
        "textlist[0.3,1;14.4,8;;"
    }
    -- Add the reports
    local reports_table = minetest_classroom.reports:to_table()["fields"]
    for k, v in pairs(reports_table) do
        mc_teacher_mail[#mc_teacher_mail + 1] = k
        mc_teacher_mail[#mc_teacher_mail + 1] = " "
        mc_teacher_mail[#mc_teacher_mail + 1] = v
        mc_teacher_mail[#mc_teacher_mail + 1] = ","
    end
    mc_teacher_mail[#mc_teacher_mail + 1] = ";1;false]"
    mc_teacher_mail[#mc_teacher_mail + 1] = "button[0.3,9.1;2,0.8;back;Back]"
    mc_teacher_mail[#mc_teacher_mail + 1] = "button[2.5,9.1;2.5,0.8;deleteall;Delete All]"
    return table.concat(mc_teacher_mail, "")
end

local function show_mail(player)
    if mc_helpers.checkPrivs(player, priv_table) then
        local pname = player:get_player_name()
        minetest.show_formspec(pname, "mc_teacher:mail", get_reports_formspec(minetest_classroom.reports))
        return true
    end
end

-- TODO: add Change Server Rules to the menu
-- Use the "rules" (Manage Server Rules) button

-- Processing the form from the menu
minetest.register_on_player_receive_fields(function(player, formname, fields)
    if string.sub(formname, 1, 10) ~= "mc_teacher" or not mc_helpers.checkPrivs(player, priv_table) then
        return false
    end

    local wait = os.clock()
    while os.clock() - wait < 0.05 do
    end --popups don't work without this

    local pname = player:get_player_name()

    -- Menu
    if formname == "mc_teacher:menu" then
        if fields.spawn then

            local spawnRealm = mc_worldManager.GetSpawnRealm()
            spawnRealm:TeleportPlayer(player)

        elseif fields.tasks then
            show_tasks(player)
        elseif fields.lessons then
            show_lessons(player)
        elseif fields.classrooms then
            show_classrooms(player)
        elseif fields.players then
            show_players(player)
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
            minetest_classroom.currenttask = "formspec_version[5]" ..
                    "size[10,12]" ..
                    "style_type[label;font_size=*1.5]" ..
                    "label[0.375,0.75;" .. fields.task .. "]" ..
                    "style[textarea;textcolor=black]" ..
                    "textarea[0.375,1.5;9.25,8;instructs;;" .. fields.instructions .. "]" ..
                    "style_type[label;font_size=*1]" ..
                    "label[0.375,9.75;You can view these task instructions again from your notebook.]" ..
                    "button_exit[0.375,10.5;2,0.8;ok;OK]"
            -- Send the task to everyone
            for _, player in pairs(minetest.get_connected_players()) do
                minetest.show_formspec(player:get_player_name(), "task:instructions", minetest_classroom.currenttask)
            end
            -- Kill any existing task timer
            task_timer.finish()
            if fields.timer ~= "" then
                if tonumber(fields.timer) > 0 then
                    timer = minetest.after(1, timer_func, tonumber(fields.timer))
                end
            end
        else
            minetest.chat_send_player(player:get_player_name(), minetest.colorize("#FF0000", "Error: Did not receive complete task or instructions. The task was not sent to players."))
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
                minetest.chat_send_player(pname, pname .. ": Course code is not valid. Expected format ABCD123. Please try again.")
                return
            end

            if string.len(fields.sectionnumber) ~= 3 then
                minetest.chat_send_player(pname, pname .. ": Section number is not valid. Expected format 123. Please try again.")
                return
            end

            -- validate that the end date is after the start date
            if tonumber(fields.endyear) == tonumber(fields.startyear) and (months[fields.endmonth] == months[fields.startmonth]) and tonumber(fields.endday) >= tonumber(fields.startday) and tonumber(string.sub(fields.endhour, 1, 2)) >= tonumber(string.sub(fields.starthour, 1, 2)) then
                minetest.chat_send_player(pname, pname .. ": Start and end dates and times must be different. Please check and try again.")
                return
            end

            if tonumber(fields.endyear) >= tonumber(fields.startyear) then
                if (months[fields.endmonth] >= months[fields.startmonth]) or (tonumber(fields.endyear) > tonumber(fields.startyear)) then
                    if tonumber(fields.endday) >= tonumber(fields.startday) then
                        if tonumber(string.sub(fields.endhour, 1, 2)) >= tonumber(string.sub(fields.starthour, 1, 2)) then
                            -- Everything checks out so proceed to encode the data to modstorage
                            record_classroom(player, fields.coursecode, fields.sectionnumber, fields.startyear, fields.startmonth, fields.startday, fields.endyear, fields.endmonth, fields.endday, fields.map)
                        else
                            minetest.chat_send_player(pname, pname .. ": Start hour must come before the end hour, day, month, and year. Please check and try again.")
                        end
                    else
                        minetest.chat_send_player(pname, pname .. ": Start day must come before the end day, month, and year. Please try again.")
                    end
                else
                    minetest.chat_send_player(pname, pname .. ": Start month must come before the end month and year. Please check and try again.")
                end
            else
                minetest.chat_send_player(pname, pname .. ": Start year must come before the end year. Please check and try again.")
            end

        elseif fields.classroomlist then
            local event = minetest.explode_textlist_event(fields.classroomlist)
            if event.type == "CHG" then
                -- "CHG" = something is selected in the list
                context.selected = event.index
            end
        elseif fields.join then
            pmeta = player:get_meta()
            pdata = minetest.deserialize(pmeta:get_string("classrooms"))
            if context.selected then
                mdata = minetest.deserialize(minetest_classroom.classrooms:get_string("classrooms"))

                local realm = Realm.realmDict[mdata.realm_id[context.selected]]
                if (realm ~= nil) then
                    realm:TeleportPlayer(player)
                else
                    minetest.chat_send_player(pname, pname .. ": Error receiving the realm / spawn coordinates. Try regenerating the classroom.")
                    minetest.log("warning", "mc_teacher gui_dash.lua: realm with ID: " .. mdata.realm_id[context.selected] .. " does not exist but is associated with a classroom.")
                end
            else
                minetest.chat_send_player(pname, pname .. ": Please click on a classroom in the list to join.")
            end
        elseif fields.back then
            show_teacher_menu(player)
        elseif fields.delete then

            if context.selected then
                pmeta = player:get_meta()
                pdata = minetest.deserialize(pmeta:get_string("classrooms"))


                -- Update modstorage first
                mdata = minetest.deserialize(minetest_classroom.classrooms:get_string("classrooms"))
                loc = check_access_code(pdata.access_code[context.selected], mdata.access_code)

                --Delete the realm
                local realm = Realm.realmDict[mdata.realm_id[loc]]
                if (realm ~= nil) then
                    realm:Delete()
                end

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
                mdata.realm_id[loc] = nil
                minetest_classroom.classrooms:set_string("classrooms", minetest.serialize(mdata
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
                pdata.realm_id[context.selected] = nil
                pmeta:set_string("classrooms", minetest.serialize(pdata
                ))

                show_classrooms(player)
            else
                minetest.chat_send_player(pname, pname .. ": Please click on a classroom in the list to delete.")
            end

            -- TODO: eventually delete this button, only useful for testing
        elseif fields.deleteall then
            pmeta:set_string("classrooms", nil)
            minetest_classroom.classrooms:set_string("classrooms", nil)
            show_classrooms(player)
        else
            -- escape without input
            return
        end
    end
end)

function record_classroom(player, cc, sn, sy, sm, sd, ey, em, ed, map)
    if mc_helpers.checkPrivs(player, priv_table) then
        local pname = player:get_player_name()
        pmeta = player:get_meta()

        -- Focus on modstorage because it is persistent and not dependent on player being online
        temp = minetest.deserialize(minetest_classroom.classrooms:get_string("classrooms"))

        -- Generate an access code
        math.randomseed(os.time())
        access_num = tostring(math.floor(math.random() * 100000))

        local newRealm = Realm:NewFromSchematic(cc .. sn .. map, map)
        newRealm:setCategoryKey("classroom")
        newRealm:AddOwner(pname)

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
                realm_id = { newRealm.ID }
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
            table.insert(temp.realm_id, newRealm.ID)
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
                realm_id = temp.realm_id
            }
        end

        -- Send to modstorage
        minetest_classroom.classrooms:set_string("classrooms", minetest.serialize(classroomdata))

        -- Send to teacher player's metadata
        pmeta:set_string("classrooms", minetest.serialize(classroomdata))
        minetest.chat_send_player(pname, pname .. ": Your course was successfully recorded.")

        -- Send player to spawn pos of classroom map
        newRealm:TeleportPlayer(player)

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

-- The controller for accessing the teacher actions
minetest.register_tool(tool_name, {
    description = "Controller for teachers",
    inventory_image = "controller.png",
    -- Left-click the tool activates the teacher menu
    on_use = function(itemstack, player, pointed_thing)
        local pname = player:get_player_name()
        -- Check for teacher privileges
        if mc_helpers.checkPrivs(player, priv_table) then
            show_teacher_menu(player)
        end
    end,
    -- Destroy the controller on_drop so that students cannot pick it up (i.e, disallow dropping without first revoking teacher)
    on_drop = function(itemstack, dropper, pos)
    end,
})
if minetest.get_modpath("mc_toolhandler") then
    mc_toolhandler.register_tool_manager(tool_name, {privs = priv_table})
end
