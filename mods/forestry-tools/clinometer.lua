
-- -- IN-PROGRESS: show yaw (horizontal angle) and pitch (vertical viewing angle) in degrees.


-- --local S = minetest.get_translator("forestry_tools")
-- local HUD_showing = false; 



-- minetest.register_tool("forestry_tools:clinometer", {
-- 	description = S("Yaw (horizontal) and Sextant (vertical)"),
-- 	_tt_help = S("Shows your pitch"),
-- 	_doc_items_longdesc = S("It shows your pitch (vertical viewing angle) in degrees. and your sextant (horizontal viewing angle) in degrees"),
-- 	_doc_items_usagehelp = use,
-- 	wield_image = "clinometer.png",
-- 	inventory_image = "clinometer.png",
-- 	groups = { disable_repair = 1 },


			
-- 		-- On left-click
--     on_use = function(itemstack, player, pointed_thing)
-- 		if HUD_showing then
-- 			clinHud:remove_all()
-- 			HUD_showing = false
-- 		else
-- 			show_clin_hud(player)
-- 		end
-- 	end,
		
--     	-- Destroy the item on_drop to keep things tidy
-- 	on_drop = function (itemstack, dropper, pos)
-- 		minetest.set_node(pos, {name="air"})
-- 	end
-- })



-- minetest.register_alias("clinometer", "forestry_tools:clinometer")
-- clinometer = minetest.registered_aliases[clinometer] or clinometer


-- -- Give the clinometer to any player who joins with adequate privileges or take it away if they do not have them
-- minetest.register_on_joinplayer(function(player)
--     local inv = player:get_inventory()
--     if inv:contains_item("main", ItemStack("forestry_tools:clinometer")) then
--         -- Player has the clinometer
--         if check_perm(player) then
--             -- The player should have the clinometer
--             return
--         else   
--             -- The player should not have the clinometer
--             player:get_inventory():remove_item('main', "forestry_tools:compass")
--         end
--     else
--         -- Player does not have the clinometer
--         if check_perm(player) then
--             -- The player should have the clinometer
--             player:get_inventory():add_item('main', "forestry_tools:clinometer")
--         else
--             -- The player should not have the clinometer
--             return
--         end     
--     end
-- end)



	
-- -- minetest.register_on_newplayer(clin_hud.init_hud)
-- -- minetest.register_on_joinplayer(clin_hud.init_hud)

-- -- minetest.register_on_leaveplayer(function(player)
-- -- 	clin_hud.playerhuds[player:get_player_name()] = nil
-- -- end)


-- local clinHud = mhud.init()
-- local function show_clin_hud(player)
-- 	clinHud:add(player, "clinometer", {
-- 		hud_elem_type = "text",
-- 		text = "",
-- 		number =  "0xFF0000",
-- 		position={x = 0.5, y = 0}, 
-- 		scale={x = 10, y = 10},
-- 		offset = {x = 0, y = 15},
-- 		z_index = 0,
			
-- 	})
-- end



-- function update_hud_displays(player)
-- 	local toDegrees = 180/math.pi
-- 	local name = player:get_player_name()
-- 	local clinometer
-- 	local pos = vector.round(player:get_pos())
	
	
-- 	if tool_active(player, "forestry_tools:clinometer") then 
-- 		clinometer = true 
-- 	end 
	
	
	
-- 	-- Minetest goes counter clokwise
-- 	local yaw = 360 - player:get_look_horizontal()*toDegrees
-- 	local pitch = player:get_look_vertical()*toDegrees
	
-- 	if (clinometer)
-- 		str_angles = S("Yaw: @1°, pitch: @2°", string.format("%.1f", yaw), string.format("%.1f", pitch))
-- 	end
	

-- 	if str_angles ~= "" then 
-- 		player:hud_change(name, "text", strs_angles)
-- 	end

	
-- 	-- issues w updating HUD 
	  


-- minetest.register_globalstep(function(dtime)
-- 	local players  = minetest.get_connected_players()
-- 	for i,player in ipairs(players) do

-- 		if HUD_showing then
-- 			-- Remove HUD when player is no longer wielding the clinometer
-- 			if player:get_wielded_item():get_name() ~= "forestry_tools:clinometer" then
-- 				clinHud:remove_all()
-- 				HUD_showing = false
-- 			else
				

-- 			-- not sure(?)
-- 			update_hud_displays(player)
    
-- 		end

			
-- 		end
-- 	end
	
-- end)
	
	
-- -- have to account for change of player FOV, direction, update HUD to display
	
-- minetest.register_on_newplayer(clinHud)
-- minetest.register_on_joinplayer(clinHud)



-- -- local clin_hud = {}
-- -- clin_hud.playerhuds = {}
-- -- clin_hud.settings = {}
-- -- clin_hud.settings.hud_pos = { x = 0.5, y = 0 }
-- -- clin_hud.settings.hud_offset = { x = 0, y = 15 }
-- -- clin_hud.settings.hud_alignment = { x = 0, y = 0 }

-- -- local set = tonumber(minetest.settings:get("clin_hud_pos_x"))
-- -- if set then clin_hud.settings.hud_pos.x = set end
-- -- set = tonumber(minetest.settings:get("clin_hud_pos_y"))
-- -- if set then clin_hud.settings.hud_pos.y = set end
-- -- set = tonumber(minetest.settings:get("clin_hud_offset_x"))
-- -- if set then clin_hud.settings.hud_offset.x = set end
-- -- set = tonumber(minetest.settings:get("clin_hud_offset_y"))
-- -- if set then clin_hud.settings.hud_offset.y = set end
-- -- set = minetest.settings:get("clin_hud_alignment")
-- -- if set == "left" then
-- -- 	clin_hud.settings.hud_alignment.x = 1
-- -- elseif set == "center" then
-- -- 	clin_hud.settings.hud_alignment.x = 0
-- -- elseif set == "right" then
-- -- 	clin_hud.settings.hud_alignment.x = -1
-- -- end

-- -- local lines = 4 -- # of HUD Lines


-- -- DIsplay player horizontal and vertical It shows you your pitch (vertical viewing angle) in degrees.



-- -- function init_hud(player)
-- -- 	update_automapper(player)
-- -- 	local name = player:get_player_name()
-- -- 	playerhuds[name] = {}
-- -- 	for i=1, o_lines do
-- -- 			playerhuds[name]["o_line"..i] = player:hud_add({
-- -- 			hud_elem_type = "text",
-- -- 			text = "",
-- -- 			position = clin_hud.settings.hud_pos,
-- -- 			offset = { x = clin_hud.settings.hud_offset.x, y = clin_hud.settings.hud_offset.y + 20*(i-1) },
-- -- 			alignment = clin_hud.settings.hud_alignment,
-- -- 			number = 0xFFFFFF,
-- -- 			scale= { x = 100, y = 20 },
-- -- 			z_index = 0,
-- -- 		})
-- -- 	end
-- -- end


-- -- function clin_hud.update_automapper(player)
-- -- 	if clin_hud.tool_active(player, "forestry_tools:clinometer") or minetest.is_creative_enabled(player:get_player_name()) then
-- -- 		player:hud_set_flags({minimap = true, minimap_radar = true})
	
-- -- 	else
-- -- 		player:hud_set_flags({minimap = false, minimap_radar = false})
-- -- 	end
-- -- end

	
