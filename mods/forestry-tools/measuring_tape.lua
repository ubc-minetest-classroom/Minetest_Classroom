-- Adapted from https://github.com/ClobberXD/mid_measure

local range = 30
local instances = {}
local data

minetest.register_on_joinplayer(function(player)
	instances[player:get_player_name()] = {
		distance = 0,
		timer_count = 0
	}

	data = {
		pos1 = {x=0, y=0, z=0},
		pos2 = {x=0, y=0, z=0},
		node1 = {name = ""},
		node2 = {name = ""},
		tape_nodes = {},
		orig_nodes = {},
		mark_status = "none_set"
	}

	local pmeta = player:get_meta()
	pmeta:set_string("measuring_tape", minetest.serialize(data))
end)

-- pos1 (start position) marker node
minetest.register_node("forestry_tools:measure_pos1", {
	description = "Measure Pos1",
	tiles = {"measure_pos1.png"},
	is_ground_content = false,
	light_source = minetest.LIGHT_MAX,
	groups = {not_in_creative_inventory, immortal}	
})

-- pos2 (end position) marker node
minetest.register_node("forestry_tools:measure_pos2", {
	description = "Measure Pos2",
	tiles = {"measure_pos2.png"},
	is_ground_content = false,
	light_source = minetest.LIGHT_MAX,
	groups = {not_in_creative_inventory, immortal}
})

-- Hud displaying distance between player and pos1
local hud = mhud.init()
local function create_hud(player, pos)
	local pmeta = player:get_meta()
	local data = minetest.deserialize(pmeta:get_string("measuring_tape"))

	hud:add(player, "measuring_tape:current_distance", {
		hud_elem_type = "waypoint",
		name = "Distance: ",
		text = "m",
		world_pos = data.pos1,
		color = 0x000000
	})
end

-- Marks pos1 and starts auto-reset counter
function mark_pos1(player, pos)
	local pname = player:get_player_name()
	local pmeta = player:get_meta()
	local data = minetest.deserialize(pmeta:get_string("measuring_tape"))

	data.pos1 = pos
	data.node1 = minetest.get_node(pos)

    -- TODO: don't want it to swap just want it to place on top
	minetest.swap_node(pos, {name = "forestry_tools:measure_pos1"})
	tell_player(pname, "Start position marked")
	data.mark_status = "pos1_set"
	pmeta:set_string("measuring_tape", minetest.serialize(data))

	-- Reads auto-reset duration from conf, defaults to 20 seconds if setting non-existent
	local auto_reset = tonumber(minetest.settings:get("forestry_tools.auto_reset"))
	if not auto_reset then
		auto_reset = 20
		minetest.settings:set("forestry_tools.auto_reset", auto_reset)
	end
			
	-- Auto-reset is disabled if auto_reset == 0
	if auto_reset ~= 0 then
		instances[pname].timer_count = instances[pname].timer_count + 1
		minetest.after(auto_reset, reset_check, player)
	end
end

-- Helper for laying tape between pos1 and pos2
local function changePos(pos, plane, change, player)
	local pmeta = player:get_meta()
	local data = minetest.deserialize(pmeta:get_string("measuring_tape"))
	pos1 = data.pos1

	local newPos
	if plane == "y" then
		if pos.y > pos1.y then change = change * -1 end
		newPos = {x = pos.x, y = pos.y + change, z = pos.z}
	elseif plane == "x" then
		if pos.x > pos1.x then change = change * -1 end
		newPos = {x = pos.x + change, y = pos.y, z = pos.z}
	else
		if pos.z > pos1.z then change = change * -1 end
		newPos = {x = pos.x, y = pos.y, z = pos.z + change}
	end

	return newPos
end

-- Marks pos2 and performs calculations
function mark_pos2(player, pos)
	local pname = player:get_player_name()
	local pmeta = player:get_meta()
	local data = minetest.deserialize(pmeta:get_string("measuring_tape"))
	pos1 = data.pos1
	node2 = data.node2

	data.pos2 = pos
	pos2 = data.pos2
	data.node2 = minetest.get_node(pos)
	minetest.swap_node(pos, {name = "forestry_tools:measure_pos2"})
	tell_player(pname, "End position marked")
	data.mark_status = "pos2_set"
	pmeta:set_string("measuring_tape", minetest.serialize(data))
	hud:remove_all()
	
	-- Calculate the distance and display output
	instances[pname].distance = math.floor(vector.distance(pos1, pos2) + 0.5)

	-- If the distance is within range, lay the tape between the start and end points
	if instances[pname].distance > range then
		tell_player(pname, "Out of range! Maximum distance is 30m")
	else
		local newPos
		for i = 1, instances[pname].distance - 1 do
			if pos.x == pos1.x then
				if pos.y == pos1.y then
					newPos = changePos(pos, "z", i, player)
				elseif pos.z == pos1.z then
					newPos = changePos(pos, "y", i, player)
				else
					newPos = changePos(pos, "y", i, player)
					newPos = changePos(newPos, "z", i, player)
				end
			elseif pos.y == pos1.y then
				if pos.z == pos1.z then
					newPos = changePos(pos, "x", i, player)
				else
					newPos = changePos(pos, "x", i, player)
					newPos = changePos(newPos, "z", i, player)
				end
			else 
				newPos = changePos(pos, "x", i, player)
				newPos = changePos(newPos, "y", i, player)
			end

			if newPos.x ~= pos1.x or newPos.y ~= pos1.y or newPos.z ~= pos1.z then
				data.tape_nodes[i] = newPos
				data.orig_nodes[i] = minetest.get_node(newPos)
				pmeta:set_string("measuring_tape", minetest.serialize(data))
				minetest.swap_node(newPos, {name = "forestry_tools:measure_pos1"})
			end
		end

		tell_player(pname, "Distance: " .. minetest.colorize("#FFFF00", instances[pname].distance) .. "m")
	end
end

-- Prevents premature auto-reset
function reset_check(player) 
	local pname = player:get_player_name()

	if instances[pname].timer_count > 0 then
		instances[pname].timer_count = instances[pname].timer_count - 1
	end

	if instances[pname].timer_count == 0 then
		reset(player)
	end
end

-- Resets pos1 and pos2; replaces marker nodes with the old nodes
function reset(player)
	local pname = player:get_player_name()
	local pmeta = player:get_meta()
	local data = minetest.deserialize(pmeta:get_string("measuring_tape"))

	local mark_status = data.mark_status

	pos1 = data.pos1
	pos2 = data.pos2
	node1 = data.node1
	node2 = data.node2
	tape_nodes = data.tape_nodes
	orig_nodes = data.orig_nodes

	if mark_status == "none_set" then
		return
	end
	
	if mark_status == "pos1_set" then
		minetest.swap_node(pos1, node1)
	elseif mark_status == "pos2_set" then
		minetest.swap_node(pos1, node1)
		minetest.swap_node(pos2, node2)

		if tape_nodes[1] ~= nil then
			for i,tapeNode in ipairs(tape_nodes) do
				minetest.swap_node(tapeNode, orig_nodes[i])
			end
		end
	end
		
	data.mark_status = "none_set"
	pmeta:set_string("measuring_tape", minetest.serialize(data))
	
	if player then
		tell_player(pname, "Tape has been reset")
	end
end

-- Convenience method which just calls minetest.chat_send_player() after prefixing msg with " -!- Measuring Tape: "
function tell_player(player_name, msg)
	minetest.chat_send_player(player_name, "Measuring Tape - " .. msg)	
end

minetest.register_on_leaveplayer(reset)

-- Included because on_leaveplayer doesn't work in singeplayer mode
minetest.register_on_shutdown(function(player)
	local players = minetest.get_connected_players()

	for _,player in pairs(players) do
		reset(player)
	end
end)

minetest.register_tool("forestry_tools:measuringTape" , {
	description = "Measuring Tape",
	inventory_image = "measuring_tape.png",
    stack_max = 1,
	liquids_pointable = true,

	-- On left-click
    on_use = function(itemstack, placer, pointed_thing)
	
		local pmeta = placer:get_meta()
		local data = minetest.deserialize(pmeta:get_string("measuring_tape"))
		if pointed_thing.type == "node" then
		
			local pointed_node = minetest.get_node(pointed_thing.under).name
			if pointed_node == "forestry_tools:measure_pos1" or pointed_node == "forestry_tools:measure_pos2" then
				reset(placer)
				return
			end
			
			mark_status = data.mark_status

			-- If pos1 not marked, mark pos1
			if mark_status == "none_set" then
				mark_pos1(placer, pointed_thing.under)
				create_hud(placer, pointed_thing.under)
			
			-- If pos1 marked, mark pos2 perform calculations, and trigger auto-reset
			elseif mark_status == "pos1_set" then
				mark_pos2(placer, pointed_thing.under)
			end
		end
		
		return itemstack
	end,

	-- Destroy the item on_drop to keep things tidy
	on_drop = function (itemstack, dropper, pos)
	end,
})

minetest.register_alias("measuringTape", "forestry_tools:measuringTape")
measuringTape = minetest.registered_aliases[measuringTape] or measuringTape

if minetest.get_modpath("mc_toolhandler") then
	mc_toolhandler.register_tool_manager("forestry_tools:measuringTape", {privs = forestry_tools.priv_table})
end
