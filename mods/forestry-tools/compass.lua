local instances = {}
local needleHud, shedHud, bezelHud, mirrorHud = mhud.init(), mhud.init(), mhud.init(), mhud.init()

minetest.register_on_joinplayer(function(player)
	instances[player:get_player_name()] = {
		closed_HUD_showing = false,
		open_HUD_showing = false,
		mag_declination = 0,
		azimuth = 0,
		curr_azimuth = 0,
		curr_needle = "needle_0.png",
		curr_bezel = "bezel_0.png",
		curr_shed = "shed_0.png",
		compassOpenHuds = {
			{ hudObject = mirrorHud, string = "mirror", text = "compass_mirror.png" },
			{ hudObject = bezelHud, string = "bezel", text = "bezel_0.png" },
			{ hudObject = shedHud, string = "shed", text = "shed_0.png" },
			{ hudObject = needleHud, string = "needle", text = "needle_0.png" }
		}
	}
end)

---------------------------
--- FORMSPEC MANAGEMENT ---
---------------------------

local adjustments_menu = {
	"formspec_version[5]",
	"size[13,7]",
	"textarea[5,0.2;3,0.5;;;Compass Settings]",
	"textarea[0.5,1.3;5,0.5;declination;Set Magnetic Declination;]",
	"textarea[0.5,2.5;5,0.5;azimuth;Set Azimuth;]",
	"button_exit[0.1,0.1;0.5,0.5;exit;X]",
	"button[8,5.8;3,0.8;save;Adjust Compass]",
	"button[0.5,3.3;3.5,0.8;getAzimuth;Get Current Azimuth]",
	"box[0.5,4.2;5,0.5;#808080]",
	"textarea[0.5,4.2;5,0.5;;;]",
	"image[4.5,-2;10,10;compass_mirror.png]",
	"image[4.5,-2;10,10;needle_0.png]",
	"image[4.5,-2;10,10;bezel_0.png]",
	"image[4.5,-2;10,10;shed_0.png]"
}

-- gives the appearance that the formspec remembers the previously set value for the given field
local function remember_field(formTableName, index, preText, newText, postText)
	local textarea = formTableName[index]
	textarea = preText .. newText .. postText
	formTableName[index] = textarea
end

local function show_adjustments_menu(player) 
	local pname = player:get_player_name()
	remember_field(adjustments_menu, 4, "textarea[0.5,1.3;5,0.5;declination;Set Magnetic Declination;", instances[pname].mag_declination, "]")
	remember_field(adjustments_menu, 5, "textarea[0.5,2.5;5,0.5;azimuth;Set Azimuth;", instances[pname].azimuth, "]")
	minetest.show_formspec(pname, "compass:adjustments_menu", table.concat(adjustments_menu, ""))
end

local function get_formspec_adjustment(hudVar, stringLen)
	local preText = "image[4.5,-2;10,10;"

	if string.len(hudVar) > stringLen then
		if string.sub(hudVar, -2, -1) == "90" then
			preText = "image[3.75,-1.26;10,10;"
		elseif string.sub(hudVar, -3, -1) == "180" then
			preText = "image[4.5,-0.55;10,10;"
		elseif string.sub(hudVar, -3, -1) == "270" then
			preText = "image[5.26,-1.26;10,10;"
		end
	end

	return preText
end

local function update_formspec_image(player, adjustNeedle, adjustBezel)
	local pname = player:get_player_name() 

	if adjustNeedle then
		adjustments_menu[12] = get_formspec_adjustment(instances[pname].curr_needle, 12) .. instances[pname].curr_needle .. "]"
	end

	if adjustBezel then
		adjustments_menu[13] = get_formspec_adjustment(instances[pname].curr_bezel, 11) .. instances[pname].curr_bezel .. "]"
	end

	adjustments_menu[14] = get_formspec_adjustment(instances[pname].curr_shed, 10) .. instances[pname].curr_shed .. "]"

	show_adjustments_menu(player)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local pname = player:get_player_name()

	if formname == "compass:adjustments_menu" then

		if fields.exit then
			adjustments_menu[10] = "textarea[0.5,4.2;5,0.5;;;]"
		end

		if fields.getAzimuth then
			adjustments_menu[10] = "textarea[0.5,4.2;5,0.5;;;" .. math.floor(instances[pname].curr_azimuth) .. "]"
			show_adjustments_menu(player)
		end

		if fields.save then
			local pmeta = player:get_meta()

			if fields.declination ~= "" and tonumber(fields.declination) ~= instances[pname].mag_declination then
				local only_nums = tonumber(fields.declination) ~= nil

				if only_nums then
					local declination_entered = tonumber(fields.declination)
					if math.abs(declination_entered) > 90 or math.abs(declination_entered) < -90 then
						minetest.chat_send_player(pname, minetest.colorize("#ff0000", "Compass - magnetic declination must be a number between -90 and 90"))
					else
						instances[pname].mag_declination = declination_entered
						pmeta:set_int("declination", instances[pname].mag_declination)

						minetest.chat_send_player(pname, minetest.colorize("#00ff00", "Compass - magnetic declination set to " .. fields.declination .. "°"))

						minetest.after(0.1, update_formspec_image, player, true, false)
					end
				else 
					minetest.chat_send_player(pname, minetest.colorize("#ff0000", "Compass - magnetic declination must be a number between -90 and 90"))
				end
			end

			if fields.azimuth ~= "" and tonumber(fields.azimuth) ~= instances[pname].azimuth then
				local only_nums = tonumber(fields.azimuth) ~= nil

				if only_nums then
					local azimuth_entered = tonumber(fields.azimuth)
					if azimuth_entered > 360 or azimuth_entered < 0 then
						minetest.chat_send_player(pname, minetest.colorize("#ff0000", "Compass - azimuth must be a number between 0 and 360"))
					else
						instances[pname].azimuth = azimuth_entered
						pmeta:set_int("azimuth", instances[pname].azimuth)

						minetest.chat_send_player(pname, minetest.colorize("#00ff00", "Compass - azimuth set to " .. fields.azimuth .. "°"))

						minetest.after(0.1, update_formspec_image, player, false, true)
					end
				else 
					minetest.chat_send_player(pname, minetest.colorize("#ff0000", "Compass - azimuth must be a number between 0 and 360"))
				end
			end

			if tonumber(fields.declination) ~= 0 and string.sub(adjustments_menu[11], 25, 26) ~= "]" then
				adjustments_menu[10] = "textarea[0.5,4.2;5,0.5;;;]"
				show_adjustments_menu(player)
			end
		end

	end
end)

--------------------------------------------
--- HUD MANAGEMENT AND TOOL REGISTRATION ---
--------------------------------------------

local closedHud = mhud.init()
local function show_closed_hud(player)
	closedHud:add(player, "closed", {
		hud_elem_type = "image",
		text = "compass_closed.png",
		position = {x = 0.5, y = 0.45}, 
		scale = {x = 5, y = 5},
		offset = {x = -4, y = -4}
	})

	instances[player:get_player_name()].closed_HUD_showing = true
end

local function show_open_huds(player) 
	for _,hud in ipairs(instances[player:get_player_name()].compassOpenHuds) do
		hud.hudObject:add(player, hud.string, {
			hud_elem_type = "image",
			text = hud.text,
			position = {x = 0.5, y = 0.45}, 
			scale = {x = 5, y = 5},
			offset = {x = -4, y = -4},
			alignment = {x = "centre", y = "centre"}
		})
	end

	instances[player:get_player_name()].open_HUD_showing = true
end

local function remove_open_huds(player)
	for _,hud in ipairs(instances[player:get_player_name()].compassOpenHuds) do
		hud.hudObject:remove_all()
	end

	instances[player:get_player_name()].open_HUD_showing = false
end

minetest.register_tool("forestry_tools:compass" , {
	description = "Compass",
	inventory_image = "compass_icon.png",
    stack_max = 1,
	liquids_pointable = true,

	-- On left-click
    on_use = function(itemstack, player, pointed_thing)
		local pname = player:get_player_name()
		local pmeta = player:get_meta()
		instances[pname].mag_declination = pmeta:get_int("declination")
		instances[pname].azimuth = pmeta:get_int("azimuth")

		if not instances[pname].closed_HUD_showing and not instances[pname].open_HUD_showing then
			show_closed_hud(player)
		elseif instances[pname].closed_HUD_showing then
			closedHud:remove_all(player)
			instances[pname].closed_HUD_showing = false

			show_open_huds(player)
		else
			remove_open_huds(player)
		end
	end,

	-- On right-click
	on_place = function(itemstack, placer, pointed_thing)
		if instances[placer:get_player_name()].open_HUD_showing then 
			update_formspec_image(placer, true, true)
		end
	end,

	on_secondary_use = function(itemstack, player, pointed_thing)
		if instances[player:get_player_name()].open_HUD_showing then 
			update_formspec_image(player, true, true)
		end
	end,

	-- Destroy the item on_drop 
	on_drop = function (itemstack, dropper, pos)
	end,
})

if minetest.get_modpath("mc_toolhandler") then
	mc_toolhandler.register_tool_manager("forestry_tools:compass", {privs = forestry_tools.priv_table})
end

minetest.register_globalstep(function(dtime)
	local players  = minetest.get_connected_players()
	for i,player in ipairs(players) do
		local pname = player:get_player_name()

		if instances[pname].closed_HUD_showing then
			if player:get_wielded_item():get_name() ~= "forestry_tools:compass" then
				closedHud:remove_all()
				instances[pname].closed_HUD_showing = false
			end
		end

		if instances[pname].open_HUD_showing then
			-- Remove HUD when player is no longer wielding the compass
			if player:get_wielded_item():get_name() ~= "forestry_tools:compass" then
				remove_open_huds(player)
				instances[pname].open_HUD_showing = false
			else
				local dir = player:get_look_horizontal()
				local angle_relative = math.deg(dir)

				-- Set magnetic declination
				if instances[pname].mag_declination > 0 and (360 - angle_relative) <= math.abs(instances[pname].mag_declination) then
					angle_relative = instances[pname].mag_declination - (360 - angle_relative)
				elseif instances[pname].mag_declination < 0 and angle_relative <= math.abs(instances[pname].mag_declination) then
					angle_relative = 360 - (math.abs(instances[pname].mag_declination) - angle_relative)
				else 
					angle_relative = math.deg(dir) + instances[pname].mag_declination
				end

				-- Update current azimuth to direction player is facing 
				instances[pname].curr_azimuth = 360 - angle_relative

				-- Rotate needle based on declination and direction player is facing
				local needle_text = rotate_texture(player, needleHud, "needle", angle_relative)
				instances[pname].curr_needle = needle_text
				needleHud:change(player, "needle", {
					text = needle_text
				})

				-- Rotate shed based on azimuth and declination set
				local shed_angle
				if instances[pname].mag_declination > 0 and instances[pname].azimuth < instances[pname].mag_declination then
					shed_angle = instances[pname].mag_declination - instances[pname].azimuth
				elseif instances[pname].mag_declination < 0 and (360 - instances[pname].azimuth) < math.abs(instances[pname].mag_declination) then
					shed_angle = instances[pname].mag_declination + instances[pname].azimuth 
				else
					shed_angle = instances[pname].mag_declination + (360 - instances[pname].azimuth)
				end

				local shed_text = rotate_texture(player, shedHud, "shed", shed_angle)
				instances[pname].curr_shed = shed_text
				shedHud:change(player, "shed", {
					text = shed_text
				})

				-- Rotate bezel based on azimuth set
				local bezel_text = rotate_texture(player, bezelHud, "bezel", (360 - instances[pname].azimuth))
				instances[pname].curr_bezel = bezel_text
				bezelHud:change(player, "bezel", {
					text = bezel_text
				})
			end
		end
	end
end)

-- Helper for rotating HUD images. The needle/bezel only show an angle change in intervals of 10, with the exception of 45°, 135°, 225°, 315°
-- e.g. the needle will be in the same position from 0°-9°, then rotate to a new position for 10°-19°, etc. (same system applies to the bezel)
-- Returns the name of the corresponding texture
local prev_bez_rotation = 0

function rotate_texture(player, hud, hudName, referenceAngle) 
	local adjustment, transformation, imgIndex
	local x, y

	if referenceAngle < 90 or referenceAngle == 360 then
		adjustment = 0
		transformation = 0
		x, y = -4, -4
	elseif referenceAngle < 180 then
		adjustment = 90
		transformation = 270
		x, y = 90, 91
	elseif referenceAngle < 270 then
		adjustment = 180
		transformation = 180
		x, y = -5, 185
	elseif referenceAngle < 360 then
		adjustment = 270
		transformation = 90
		x, y = -99, 91
	end

	hud:change(player, hudName, {
		offset = {x = x, y = y}
	})

	if math.floor(referenceAngle % 45) <= 4 and not (math.floor(referenceAngle % 90) <= 9) then
		imgIndex = 4.5
	elseif referenceAngle == 360 then
		imgIndex = 0
	else
		imgIndex = math.floor((referenceAngle - adjustment)/10)
	end

	return hudName .. "_" .. imgIndex .. ".png" .. "^[transformR" .. transformation
end
