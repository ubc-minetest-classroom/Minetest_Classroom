local degreePlus0Hud, degreePlus10Hud, degreePlus20Hud, degreeMinus10Hud, degreeMinus20Hud = mhud.init(), mhud.init(), mhud.init(), mhud.init(), mhud.init()
local percentPlus0Hud, percentPlus10Hud, percentPlus20Hud, percentPlus30Hud, percentPlus40Hud = mhud.init(), mhud.init(), mhud.init(), mhud.init(), mhud.init()
local percentMinus10Hud, percentMinus20Hud, percentMinus30Hud, percentMinus40Hud = mhud.init(), mhud.init(), mhud.init(), mhud.init()

local instances = {}

minetest.register_on_joinplayer(function(player)
	instances[player:get_player_name()] = {
		HUD_showing = false,
		curr_pitch = 0,
		curr_percent = 0,
		bg_angle = "0",
		measurementHuds = {
			{ hudObject = degreePlus0Hud, string = "degreePlus0", xAlignment = "left", xOffset = -40, yOffset = -4, value = 0 },
			{ hudObject = degreePlus10Hud, string = "degreePlus10", xAlignment = "left", xOffset = -40, yOffset = -70, value = 0 },
			{ hudObject = degreePlus20Hud, string = "degreePlus20", xAlignment = "left", xOffset = -40, yOffset = -135, value = 0 },
			{ hudObject = degreeMinus10Hud, string = "degreeMinus10", xAlignment = "left", xOffset = -40, yOffset = 62, value = 0 },
			{ hudObject = degreeMinus20Hud, string = "degreeMinus20", xAlignment = "left", xOffset = -40, yOffset = 125, value = 0 },
			{ hudObject = percentPlus0Hud, string = "percentPlus0", xAlignment = "right", xOffset = 35, yOffset = -4, value = 0 },
			{ hudObject = percentPlus10Hud, string = "percentPlus10", xAlignment = "right", xOffset = 35, yOffset = -43, value = 0 },
			{ hudObject = percentPlus20Hud, string = "percentPlus20", xAlignment = "right", xOffset = 35, yOffset = -83, value = 0 },
			{ hudObject = percentPlus30Hud, string = "percentPlus30", xAlignment = "right", xOffset = 35, yOffset = -120, value = 0 },
			{ hudObject = percentPlus40Hud, string = "percentPlus40", xAlignment = "right", xOffset = 35, yOffset = -160, value = 0 },
			{ hudObject = percentMinus10Hud, string = "percentMinus10", xAlignment = "right", xOffset = 35, yOffset = 37, value = 0 },
			{ hudObject = percentMinus20Hud, string = "percentMinus20", xAlignment = "right", xOffset = 35, yOffset = 75, value = 0 },
			{ hudObject = percentMinus30Hud, string = "percentMinus30", xAlignment = "right", xOffset = 35, yOffset = 115, value = 0 },
			{ hudObject = percentMinus40Hud, string = "percentMinus40", xAlignment = "right", xOffset = 35, yOffset = 153, value = 0 }
		}
	}
end)

local function show_measurement_hud(player, hudObject, string, xAlignment, xOffset, yOffset)
	hudObject:add(player, string, {
		hud_elem_type = "text",
		text = "",
		alignment = {x = xAlignment, y = "centre"},
		position = {x = 0.7, y = 0.5}, 
		scale = {x = 6.5, y = 6.5},
		offset = {x = xOffset, y = yOffset}
	})
end

local bgHud = mhud.init()
local function show_bg_hud(player)
	bgHud:add(player, "background", {
		hud_elem_type = "image",
		text = "clinometer_0.png",
		position = {x = 0.7, y = 0.5}, 
		scale = {x = 6.5, y = 6.5},
		offset = {x = -4, y = -4}
	})

	instances[player:get_player_name()].HUD_showing = true
end

local function show_all_huds(player)
	show_bg_hud(player)

	for _,hud in ipairs(instances[player:get_player_name()].measurementHuds) do
		show_measurement_hud(player, hud.hudObject, hud.string, hud.xAlignment, hud.xOffset, hud.yOffset)
	end
	instances[player:get_player_name()].HUD_showing = true
end

local function hide_huds(player)
	bgHud:remove_all()

	for _,hud in ipairs(instances[player:get_player_name()].measurementHuds) do
		hud.hudObject:remove_all()
	end
	instances[player:get_player_name()].HUD_showing = false
end

minetest.register_tool("forestry_tools:clinometer" , {
	description = "Clinometer",
	inventory_image = "clinometer_icon.png",
    stack_max = 1,
	liquids_pointable = true,

	-- On left-click
    on_use = function(itemstack, player, pointed_thing)
		if instances[player:get_player_name()].HUD_showing then
			hide_huds(player)
		else
			show_all_huds(player)
		end
	end,

	-- Destroy the item on_drop 
	on_drop = function (itemstack, dropper, pos)
	end,
})

if minetest.get_modpath("mc_toolhandler") then
	mc_toolhandler.register_tool_manager("forestry_tools:clinometer", {privs = forestry_tools.priv_table})
end

local function update_hud(player, hud, hudname, text) 
	local newtext
	if hudname == "background" then
		newtext = "clinometer_" .. text .. ".png"
	else
		newtext = text
	end

	hud:change(player, hudname, {
		text = newtext
	})
end

local function update_clinometer(player)
	local pname = player:get_player_name()
	instances[pname].bg_angle = "0"

	-- degPlus0, degPlus10, degPlus20, degMinus10, degMinus20
	instances[pname].measurementHuds[1].value, instances[pname].measurementHuds[2].value, instances[pname].measurementHuds[3].value, instances[pname].measurementHuds[4].value, instances[pname].measurementHuds[5].value = tostring(instances[pname].curr_pitch), tostring(instances[pname].curr_pitch + 10), tostring(instances[pname].curr_pitch + 20), tostring(instances[pname].curr_pitch - 10), tostring(instances[pname].curr_pitch - 20)
	-- percentPlus0, percentPlus10, percentPlus20, percentPlus30, percentPlus40
	instances[pname].measurementHuds[6].value, instances[pname].measurementHuds[7].value, instances[pname].measurementHuds[8].value, instances[pname].measurementHuds[9].value, instances[pname].measurementHuds[10].value = tostring(instances[pname].curr_percent), tostring(instances[pname].curr_percent + 10), tostring(instances[pname].curr_percent + 20), tostring(instances[pname].curr_percent + 30), tostring(instances[pname].curr_percent + 40)
	-- percentMinus10, percentMinus20, percentMinus30, percentMinus40
	instances[pname].measurementHuds[11].value, instances[pname].measurementHuds[12].value, instances[pname].measurementHuds[13].value, instances[pname].measurementHuds[14].value = tostring(instances[pname].curr_percent - 10), tostring(instances[pname].curr_percent - 20), tostring(instances[pname].curr_percent - 30), tostring(instances[pname].curr_percent - 40)


	if (instances[pname].curr_percent + 40) < -1000 then
		-- percentPlus10, percentPlus20, percentPlus30, percentPlus40
		instances[pname].measurementHuds[7].value, instances[pname].measurementHuds[8].value, instances[pname].measurementHuds[9].value, instances[pname].measurementHuds[10].value = "∞", "∞", "∞", "∞"
	elseif (instances[pname].curr_percent + 30) < -1000 then
		-- percentPlus10, percentPlus20, percentPlus30
		instances[pname].measurementHuds[7].value, instances[pname].measurementHuds[8].value, instances[pname].measurementHuds[9].value = "∞", "∞", "∞"
	elseif (instances[pname].curr_percent + 20) < -1000 then
		-- percentPlus10, percentPlus20
		instances[pname].measurementHuds[7].value, instances[pname].measurementHuds[8].value = "∞", "∞"
	elseif (instances[pname].curr_percent + 10) > 1000 or (instances[pname].curr_percent + 10) < -1000 then
		-- percentPlus10
		instances[pname].measurementHuds[7].value = "∞"
	end

	if (instances[pname].curr_percent - 40) > 1000 then
		-- percentMinus10, percentMinus20, percentMinus30, percentMinus40
		instances[pname].measurementHuds[11].value, instances[pname].measurementHuds[12].value, instances[pname].measurementHuds[13].value, instances[pname].measurementHuds[14].value = "∞", "∞", "∞", "∞"
	elseif (instances[pname].curr_percent - 30) > 1000 then
		-- percentMinus10, percentMinus20, percentMinus30
		instances[pname].measurementHuds[11].value, instances[pname].measurementHuds[12].value, instances[pname].measurementHuds[13].value = "∞", "∞", "∞"
	elseif (instances[pname].curr_percent - 20) > 1000 then
		-- percentMinus10, percentMinus20
		instances[pname].measurementHuds[11].value, instances[pname].measurementHuds[12].value = "∞", "∞"
	elseif (instances[pname].curr_percent - 10) > 1000 or (instances[pname].curr_percent - 10) < -1000 then
		-- percentMinus10
		instances[pname].measurementHuds[11].value = "∞"
	end

	if instances[pname].curr_pitch >= 70 and instances[pname].curr_pitch < 80 then
		instances[pname].bg_angle = "70"
		-- percentPlus40
		instances[pname].measurementHuds[10].value = ""
	elseif instances[pname].curr_pitch >= 80 and instances[pname].curr_pitch < 89 then
		instances[pname].bg_angle = "80"
		-- percentPlus20, percentPlus30, percentPlus40
		instances[pname].measurementHuds[8].value, instances[pname].measurementHuds[9].value, instances[pname].measurementHuds[10].value = "", "", ""
		-- degreePlus20
		instances[pname].measurementHuds[3].value = ""
	elseif instances[pname].curr_pitch >= 89 then
		instances[pname].bg_angle = "90"
		-- percentPlus10, percentPlus20, percentPlus30, percentPlus40
		instances[pname].measurementHuds[7].value, instances[pname].measurementHuds[8].value, instances[pname].measurementHuds[9].value, instances[pname].measurementHuds[10].value = "", "", "", ""
		-- degreePlus10, degreePlus20
		instances[pname].measurementHuds[2].value, instances[pname].measurementHuds[3].value = "", ""
	elseif instances[pname].curr_pitch <= -70 and instances[pname].curr_pitch > -80 then
		instances[pname].bg_angle = "70.1"
		-- percentMinus40
		instances[pname].measurementHuds[14].value = ""
	elseif instances[pname].curr_pitch <= -80 and instances[pname].curr_pitch > -89 then
		instances[pname].bg_angle = "80.1"
		-- percentMinus20, percentMinus30, percentMinus40
		instances[pname].measurementHuds[12].value, instances[pname].measurementHuds[13].value, instances[pname].measurementHuds[14].value = "", "", ""
		-- degreeMinus20
		instances[pname].measurementHuds[5].value = ""
	elseif instances[pname].curr_pitch <= -89 then
		instances[pname].bg_angle = "90.1"
		-- percentMinus10, percentMinus20, percentMinus30, percentMinus40
		instances[pname].measurementHuds[11].value, instances[pname].measurementHuds[12].value, instances[pname].measurementHuds[13].value, instances[pname].measurementHuds[14].value = "", "", "", ""
		-- degreeMinus10, degreeMinus20
		instances[pname].measurementHuds[4].value, instances[pname].measurementHuds[5].value = "", ""
	end

	update_hud(player, bgHud, "background", instances[pname].bg_angle) 

	for i,hud in ipairs(instances[pname].measurementHuds) do
		if i == 6 then
			if instances[pname].curr_percent > 1000 or instances[pname].curr_percent < -1000 then
				update_hud(player, hud.hudObject, hud.string, "∞") 
			else
				update_hud(player, hud.hudObject, hud.string, tostring(instances[pname].curr_percent)) 
			end
		else
			update_hud(player, hud.hudObject, hud.string, hud.value)
		end
	end
end


minetest.register_globalstep(function(dtime)
	local players  = minetest.get_connected_players()
	for i,player in ipairs(players) do
		local pname = player:get_player_name()

		if instances[pname].HUD_showing then
			if player:get_wielded_item():get_name() ~= "forestry_tools:clinometer" then
				hide_huds(player)
			else
				local pitch_rad = player:get_look_vertical()
				local pitch = -1 * math.deg(pitch_rad)
				instances[pname].curr_pitch = math.floor(pitch)

				instances[pname].curr_percent = math.floor(-100 * math.tan(pitch_rad))

				update_clinometer(player)
			end
		end
	end
end)
