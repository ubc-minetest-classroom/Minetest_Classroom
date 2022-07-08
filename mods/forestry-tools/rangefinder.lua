--[[ TODO
-- Add random chance for noise/skipping when raycast hits nodes with:
  -- node group: leaves
  -- drawtype: plantlike, plantlike_rooted
-- Add calculation/cast outputs to HUD instead of chat
-- Auto-reset?
]]

--[[ CURRENT CONTROL SCHEME
-- L-CLICK               = take measurement/reset
-- L-CLICK + AUX         = undo previous measurement (WIP)
-- L-CLICK + SNEAK       = open measurement settings (WIP)
-- L-CLICK + AUX + SNEAK = reset measurement (WIP)

-- R-CLICK               = cycle (forwards)
-- R-CLICK + AUX         = cycle (reverse)
-- R-CLICK + SNEAK       = cycle routine (forwards)
-- R-CLICK + AUX + SNEAK = cycle routine (reverse)
]]

local range = 32 -- extraneous

local RAY_RANGE = 500
local ROUTINES = {
    [1] = {key = "--", casts = 1, desc = "measurement", modes = {
        [1] = {key = "SD", unit = "m"},
        [2] = {key = "VD", unit = "m"},
        [3] = {key = "HD", unit = "m"},
        [4] = {key = "INC", unit = "%"},
        [5] = {key = "AZ", unit = "°"}
    }},
    [2] = {key = "HT", casts = 3, desc = "height", modes = {
        [1] = {key = "HT", unit = "m"}
    }},
    [3] = {key = "ML", casts = 2, desc = "missing line", modes = {
        [1] = {key = "SD", unit = "m"},
        [2] = {key = "VD", unit = "m"},
        [3] = {key = "HD", unit = "m"},
        [4] = {key = "INC", unit = "%"},
        [5] = {key = "AZ", unit = "°"}
    }}
}
local MRHUD_POS = {x = 0.0725, y = 0.857}
local MRHUD_OFFSET = {x = 5, y = -5} -- {x = 0, y = 0}
local MRHUD_BG_SCALE = {x = -14.5, y = -19}
local SUB_BG_SCALE = {x = -6, y = -4.8}
local TOOL_NAME = "forestry_tools:rangefinder"

local hud = mhud.init()
local mrhud_mode_hud = mhud.init()

-- Gets the internal index number for the rangefinder's current routine
local function get_routine(meta)
    return tonumber(meta:get("routine") or 1)
end

-- Gets the internal index number for the rangefinder's current mode
local function get_mode(meta)
    return tonumber(meta:get("mode") or 1)
end

-- Constrains val to the open domain defined by [min, max]
local function constrain(min, val, max)
    return math.max(min, math.min(max, val))
end

-- Clears all the logged casts from the rangefinder's metadata
local function clear_saved_casts(player, itemstack)
    local meta = itemstack:get_meta()
    local count = 0
    meta:set_string("casts", "")
    local mark_table = minetest.deserialize(meta:get("marks") or minetest.serialize({}))
    for i,id in pairs(mark_table) do
        if hud:get(player, id) then
            hud:remove(player, id)
        end
        count = count + 1
    end
    meta:set_string("marks", "")

    if count > 0 then
        minetest.chat_send_player(player:get_player_name(), "Rangefinder reset, ready to start new measurement")
    end
    return itemstack
end

-- Adds a cast market to the world
local function add_cast_marker(player, pos, is_angle)
    return hud:add(player, nil, {
        hud_elem_type = "image_waypoint",
        world_pos = pos,
        text = is_angle and "forestry_tools_rf_anglemarker.png" or "forestry_tools_rf_marker.png",
        scale = {x = 1.5, y = 1.5},
        z_index = is_angle and -301 or -300,
        alignment = {x = 0, y = 0}
    })
end

-- Casts a ray and logs where it first hit, if it hit an object/node in range
local function track_raycast_hit(player, itemstack)
    local meta = itemstack:get_meta()
    if meta then
        -- log hit in rangefinder
        local cast_table = minetest.deserialize(meta:get("casts") or minetest.serialize({}))
        local mark_table = minetest.deserialize(meta:get("marks") or minetest.serialize({}))
        local routine = get_routine(meta)

        if #cast_table >= ROUTINES[routine]["casts"] then
            -- clear hits
            return clear_saved_casts(player, itemstack), nil, nil
        end

        local player_pos = vector.offset(player:get_pos(), 0, player:get_properties().eye_height, 0)
        local ray = minetest.raycast(player_pos, vector.add(player_pos, vector.multiply(player:get_look_dir(), RAY_RANGE)))
        local cast_point, first_hit = ray:next(), ray:next()

        if not first_hit then
            -- no objects/nodes within range, note failed hit
            minetest.chat_send_player(player:get_player_name(), "Nothing detected within a 500m range, measurement not tracked")
            return itemstack, nil, nil
        end

        local dir = vector.direction(cast_point.intersection_point, first_hit.intersection_point)
        local dist = vector.distance(cast_point.intersection_point, first_hit.intersection_point)
        table.insert(cast_table, {dir = dir, dist = dist, pos = first_hit.intersection_point})
        meta:set_string("casts", minetest.serialize(cast_table))

        -- display hit on screen + log ID in rangefinder
        table.insert(mark_table, add_cast_marker(player, first_hit.intersection_point, routine == 2 and #mark_table ~= 0))
        meta:set_string("marks", minetest.serialize(mark_table))

        local table_length = math.min(#cast_table, #mark_table)
        local casts_reached = table_length >= ROUTINES[routine]["casts"]
        return itemstack, table_length, casts_reached
    end
end

--- Creates a HUD text element for the rangefinder's mode display
local function mode_hud_text_abstract(player, hud, oper, elem, text, pos_offset, col, size, style)
    local def = {
        hud_elem_type = "text",
        position = {x = MRHUD_POS.x + (pos_offset and pos_offset.x or 0), y = MRHUD_POS.y + (pos_offset and pos_offset.y or 0)},
        alignment = {x = 0, y = 0},
        offset = MRHUD_OFFSET,
        color = col or 0xFFFFFF,
        scale = {x = 100, y = 100},
        text = text or "",
        text_scale = size or 1,
        style = style or 0,
        z_index = 1,
    }
    if oper == "add" then
        hud:add(player, elem, def)
    elseif oper == "change" then
        hud:change(player, elem, def)
    end
end

-- Creates the background for the rangefinder's mode display
local function create_mode_hud_background(player)
    if not hud:get(player, TOOL_NAME..":MRHUD:routine_bg") then
        local shift = (math.abs(MRHUD_BG_SCALE.y) + math.abs(SUB_BG_SCALE.y)) / 200

        hud:add(player, TOOL_NAME..":MRHUD:routine_bg", {
            hud_elem_type = "image",
            position = MRHUD_POS,
            alignment = {x = 0, y = 0},
            offset = MRHUD_OFFSET,
            scale = MRHUD_BG_SCALE,
            text = "forestry_tools_pixel.png^[colorize:#000000:255^[opacity:127",
            z_index = -2,
        })
        hud:add(player, TOOL_NAME..":MRHUD:routine_bg_u", {
            hud_elem_type = "image",
            position = {x = MRHUD_POS.x, y = MRHUD_POS.y - shift},
            alignment = {x = 0, y = 0},
            offset = MRHUD_OFFSET,
            scale = SUB_BG_SCALE,
            text = "forestry_tools_pixel.png^[colorize:#39403b:255^[opacity:127",
            z_index = -3,
        })
        hud:add(player, TOOL_NAME..":MRHUD:routine_bg_l", {
            hud_elem_type = "image",
            position = {x = MRHUD_POS.x, y = MRHUD_POS.y + shift},
            alignment = {x = 0, y = 0},
            offset = MRHUD_OFFSET,
            scale = SUB_BG_SCALE,
            text = "forestry_tools_pixel.png^[colorize:#39403b:255^[opacity:127",
            z_index = -3,
        })
    end
end

-- Creates the mode display area for the rangefinder's routine/mode HUD
local function update_mode_hud_modes(player, routine, mode)
    local mode_count = #ROUTINES[routine]["modes"]

    -- clear mode hud to prevent element overlap
    mrhud_mode_hud:remove(player)
    if mode_count == 1 then
        return -- only 1 mode in routine, do not display
    end

    local spacer = 0.1
    local scale = {x = -5, y = (math.abs(MRHUD_BG_SCALE.y) - spacer * (mode_count - 1)) / -mode_count}
    local shift_x = (math.abs(MRHUD_BG_SCALE.x / 2) + math.abs(scale.x / 2) + spacer) / 100
    local initial_y = (math.abs(scale.y) - math.abs(MRHUD_BG_SCALE.y))/200

    for i,mode_data in ipairs(ROUTINES[routine]["modes"]) do
        local offset_y = initial_y + ((i - 1)*(math.abs(scale.y) + spacer)/100)
        mrhud_mode_hud:add(player, TOOL_NAME..":MRHUD:mode_"..i, {
            hud_elem_type = "image",
            position = {x = MRHUD_POS.x + shift_x, y = MRHUD_POS.y + offset_y},
            alignment = {x = 0, y = 0},
            offset = MRHUD_OFFSET,
            scale = scale,
            text = (i == mode and "forestry_tools_pixel.png^[colorize:#7a968b:255^[opacity:159") or "forestry_tools_pixel.png^[colorize:#39403b:255^[opacity:127",
            z_index = -3,
        })
        mode_hud_text_abstract(player, mrhud_mode_hud, "add", TOOL_NAME..":MRHUD:mode_"..i.."_text", mode_data["key"], {x = shift_x, y = offset_y}, (i == mode and 0xffffff) or 0xd0d0d0, (i == mode and 2) or 1, 5)
    end
end

-- Creates the arrows indicating the current mode change direction for the rangefinder's mode display
local function update_mode_hud_arrows(player, keys)
    --[[local arrow_u = {
        hud_elem_type = "image",
        position = {x = MRHUD_POS.x, y = MRHUD_POS.y - 0.063},
        alignment = {x = 0, y = 0},
        offset = MRHUD_OFFSET,
        scale = (keys.aux1 and {x = -0.75, y = -0.75}) or {x = -1.25, y = -1.25},
        text = (keys.aux1 and "forestry_tools_rf_arrow_up.png") or "forestry_tools_rf_arrow_up.png^[transformFY",
        z_index = -1,
    }
    local arrow_l = {
        hud_elem_type = "image",
        position = {x = MRHUD_POS.x, y = MRHUD_POS.y + 0.063},
        alignment = {x = 0, y = 0},
        offset = MRHUD_OFFSET,
        scale = (keys.aux1 and {x = -1.25, y = -1.25}) or {x = -0.75, y = -0.75},
        text = (keys.aux1 and "forestry_tools_rf_arrow_up.png") or "forestry_tools_rf_arrow_up.png^[transformFY",
        z_index = -1,
    }

    if not hud:get(player, TOOL_NAME..":MRHUD:arrow_u") then
        hud:add(player, TOOL_NAME..":MRHUD:arrow_u", arrow_u)
        hud:add(player, TOOL_NAME..":MRHUD:arrow_l", arrow_l)
    else
        hud:change(player, TOOL_NAME..":MRHUD:arrow_u", arrow_u)
        hud:change(player, TOOL_NAME..":MRHUD:arrow_l", arrow_l)
    end]]
end

-- Updates the rangefinder's mode display
local function update_rf_mode_hud(player, itemstack)
    local meta = itemstack:get_meta()
    if meta then
        local routine = constrain(1, get_routine(meta), #ROUTINES)
        local mode = constrain(1, get_mode(meta), #ROUTINES[routine]["modes"])
        local surround = {
            next = (routine + 1 <= #ROUTINES and routine + 1) or 1,
            prev = (routine - 1 >= 1 and routine - 1) or #ROUTINES
        }
        local cast_desc = ROUTINES[routine]["casts"] == 1 and "1 cast" or ROUTINES[routine]["casts"].." casts"
        local sub_shift = (math.abs(MRHUD_BG_SCALE.y) + math.abs(SUB_BG_SCALE.y)) / 200

        local mode_hud_exists = hud:get(player, TOOL_NAME..":MRHUD:routine")
        mode_hud_text_abstract(player, hud, (mode_hud_exists and "change") or "add", TOOL_NAME..":MRHUD:routine", ROUTINES[routine]["key"], {y = -0.045}, nil, 5, 5)
        mode_hud_text_abstract(player, hud, (mode_hud_exists and "change") or "add", TOOL_NAME..":MRHUD:routine_desc", ROUTINES[routine]["desc"], {y = 0.025}, nil, 2, 0)
        mode_hud_text_abstract(player, hud, (mode_hud_exists and "change") or "add", TOOL_NAME..":MRHUD:routine_cast_desc", cast_desc, {y = 0.065}, nil, 2, 0)
        mode_hud_text_abstract(player, hud, (mode_hud_exists and "change") or "add", TOOL_NAME..":MRHUD:routine_prev", ROUTINES[surround.prev]["key"], {y = sub_shift}, 0xcacfcd, 2, 4)
        mode_hud_text_abstract(player, hud, (mode_hud_exists and "change") or "add", TOOL_NAME..":MRHUD:routine_next", ROUTINES[surround.next]["key"], {y = -sub_shift}, 0xcacfcd, 2, 4)
        
        update_mode_hud_modes(player, routine, mode)
        create_mode_hud_background(player)
    end
end

-- Shows the rangefinder's zooming crosshair
local function show_zoom_hud(player)
    if not hud:get(player, TOOL_NAME..":crosshair") then
        hud:add(player, TOOL_NAME..":crosshair", {
            hud_elem_type = "image",
            position = {x = 0.5, y = 0.5},
            text = "forestry_tools_rf_crosshair.png",
            scale = {x = -60, y = -60},
            z_index = -100,
            alignment = {x = 0, y = 0}
        })
    end
end

-- Hides the rangefinder's zooming crosshair
local function hide_zoom_hud(player)
    if hud:get(player, TOOL_NAME..":crosshair") then
        hud:remove(player, TOOL_NAME..":crosshair")
    end
end

-- Rounds num to the given number of decimal places
local function round_to_decim_places(num, places, as_string)
    if type(num) ~= "number" then
        return num
    end

    local factor = 10^places
    local round_num = math.round(num * factor)
    if not as_string then
        return round_num / factor
    else
        local num_string = tostring(round_num)
        local whole = string.sub(num_string, 1, -1 - places)
        local decim = string.sub(num_string, -places)
        return decim ~= "" and (whole ~= "" and whole or "0").."."..decim or (whole ~= "" and whole or "0")
    end
end

-- Returns the length of the side of a triangle opposite angle theta, given theta and the other two side lengths
local function cosine_law(a, b, theta)
    return math.sqrt(a^2 + b^2 - 2*a*b*math.cos(theta))
end

-- Calculates the final output for the rangefinder to display
local function rangefinder_calc(meta)
    local casts = minetest.deserialize(meta:get_string("casts"))
    local routine = get_routine(meta)
    local mode = get_mode(meta)
    if not casts or #casts < ROUTINES[routine]["casts"] then
        return nil
    end

    local calculation_table = {
        [1] = { -- measurement (--)
            [1] = function() -- SD
                return casts[1]["dist"]
            end,
            [2] = function() -- VD
                local slope_dist = casts[1]["dist"]
                local slope_dir = casts[1]["dir"]
                local theta = vector.angle(slope_dir, vector.new(slope_dir.x, 0, slope_dir.z))
                return slope_dist * math.sin(theta) * math.sign(slope_dir.y)
            end,
            [3] = function() -- HD
                local slope_dist = casts[1]["dist"]
                local slope_dir = casts[1]["dir"]
                local theta = vector.angle(slope_dir, vector.new(slope_dir.x, 0, slope_dir.z))
                return slope_dist * math.cos(theta)
            end,
            [4] = function() -- INC
                local slope_dist = casts[1]["dist"]
                local slope_dir = casts[1]["dir"]
                local theta = vector.angle(slope_dir, vector.new(slope_dir.x, 0, slope_dir.z))
                local horiz_dist = slope_dist * math.cos(theta) 
                local verti_dist = slope_dist * math.sin(theta) * math.sign(slope_dir.y)
                return 100 * verti_dist / horiz_dist
            end,
            [5] = function() -- AZ
                return routine..":"..mode -- stub
            end
        },
        [2] = { -- height (HT)
            [1] = function() -- HT
                local gamma = vector.angle(casts[1]["dir"], vector.new(casts[1]["dir"]["x"], 0, casts[1]["dir"]["z"]))
                local alpha = vector.angle(casts[2]["dir"], vector.new(casts[2]["dir"]["x"], 0, casts[2]["dir"]["z"]))
                local beta = vector.angle(casts[3]["dir"], vector.new(casts[3]["dir"]["x"], 0, casts[3]["dir"]["z"]))
                local horiz_dist = casts[1]["dist"] * math.cos(gamma)
                local theta = nil
                if math.sign(casts[2]["dir"]["y"]) == math.sign(casts[3]["dir"]["y"]) then
                    theta = math.abs(alpha - beta)
                else
                    theta = math.abs(alpha + beta)
                end
                return cosine_law(horiz_dist/math.cos(alpha), horiz_dist/math.cos(beta), theta)
            end
        },
        [3] = { -- missing line (ML)
            [1] = function() -- SD
                return cosine_law(casts[1]["dist"], casts[2]["dist"], vector.angle(casts[1]["dir"], casts[2]["dir"]))
            end,
            [2] = function() -- VD
                local vect_a = vector.multiply(casts[1]["dir"], casts[1]["dist"])
                local vect_b = vector.multiply(casts[2]["dir"], casts[2]["dist"])
                local slope_vect = vector.subtract(vect_b, vect_a)
                local phi = vector.angle(slope_vect, vector.new(slope_vect.x, 0, slope_vect.z))
                return vector.length(slope_vect) * math.sin(phi) * math.sign(slope_vect.y)
            end,
            [3] = function() -- HD
                local vect_a = vector.multiply(casts[1]["dir"], casts[1]["dist"])
                local vect_b = vector.multiply(casts[2]["dir"], casts[2]["dist"])
                local slope_vect = vector.subtract(vect_b, vect_a)
                local phi = vector.angle(slope_vect, vector.new(slope_vect.x, 0, slope_vect.z))
                return vector.length(slope_vect) * math.cos(phi)
            end,
            [4] = function() -- INC
                local vect_a = vector.multiply(casts[1]["dir"], casts[1]["dist"])
                local vect_b = vector.multiply(casts[2]["dir"], casts[2]["dist"])
                local slope_vect = vector.subtract(vect_b, vect_a)
                local phi = vector.angle(slope_vect, vector.new(slope_vect.x, 0, slope_vect.z))
                local horiz_dist = vector.length(slope_vect) * math.cos(phi)
                local verti_dist = vector.length(slope_vect) * math.sin(phi) * math.sign(slope_vect.y)
                return 100 * verti_dist / horiz_dist
            end,
            [5] = function() -- AZ
                return routine..":"..mode -- stub
            end
        }
    }
    return calculation_table[routine][mode]()
end

-- Changes the rangefinder's mode
local function rangefinder_mode_switch(itemstack, player, pointed_thing)
    local meta = itemstack:get_meta()
    local cur_routine = get_routine(meta)
    local cur_mode = get_mode(meta)
    local keys = player:get_player_control()
    local new_routine, new_mode = cur_routine, cur_mode

    if keys.sneak then
        if keys.aux1 then
            -- cycle routine backwards
            new_routine = (cur_routine - 1 >= 1 and cur_routine - 1) or #ROUTINES
        else
            -- cycle routine forwards
            new_routine = (cur_routine + 1 <= #ROUTINES and cur_routine + 1) or 1
        end
        new_mode = ROUTINES[new_routine]["modes"] and 1 or nil
    else
        if keys.aux1 then
            -- cycle mode backwards, switch routines if at end
            new_mode = cur_mode - 1
            if new_mode < 1 then
                new_routine = (cur_routine - 1 >= 1 and cur_routine - 1) or #ROUTINES
                new_mode = ROUTINES[new_routine]["modes"] and #ROUTINES[new_routine]["modes"] or nil
            end
        else
            -- cycle mode forwards, switch routines if at end
            new_mode = cur_mode + 1
            if new_mode > #ROUTINES[cur_routine]["modes"] then
                new_routine = (cur_routine + 1 <= #ROUTINES and cur_routine + 1) or 1
                new_mode = ROUTINES[new_routine]["modes"] and 1 or nil
            end
        end
    end

    meta:set_int("mode", new_mode)
    meta:set_int("routine", new_routine)
    
    update_rf_mode_hud(player, itemstack)
    if cur_routine ~= new_routine then
        clear_saved_casts(player, itemstack)
    else
        local result = rangefinder_calc(meta)
        if result then
            local round_res = round_to_decim_places(result, 1, true)
            minetest.chat_send_player(player:get_player_name(), "Measurement for new mode: "..round_res..ROUTINES[new_routine]["modes"][new_mode]["unit"])
        end
    end
    return itemstack
end

minetest.register_tool(TOOL_NAME, {
 	description = "Rangefinder",
 	inventory_image = "rangefinder.jpg",
    _mc_tool_privs = { interact = true },
 	-- Left-click the tool activate function
 	on_use = function(itemstack, player, pointed_thing)
        local pname = player:get_player_name()
 		-- Check for shout privileges
 		if forestry_tools.check_perm(player) then
            local new_stack, cast_num, cast_complete = track_raycast_hit(player, itemstack)
            if new_stack then
                local meta = new_stack:get_meta()
                -- log cast distance
                if cast_num then
                    local casts = minetest.deserialize(meta:get_string("casts"))
                    if casts[cast_num] then
                        local cast_dist = round_to_decim_places(casts[cast_num]["dist"], 1, true)
                        minetest.chat_send_player(pname, "Cast "..cast_num.." logged - distance: "..cast_dist.."m")
                    end
                end
                -- perform and log calculation
                if cast_complete then
                    local result = rangefinder_calc(meta)
                    local routine = get_routine(meta)
                    local mode = get_mode(meta)
                    if result then
                        local round_res = round_to_decim_places(result, 1, true)
                        minetest.chat_send_player(pname, "Final measurement: "..round_res..ROUTINES[routine]["modes"][mode]["unit"])
                    end
                end
            end
            -- Register a node punch
            if pointed_thing.under then
                minetest.node_punch(pointed_thing.under, minetest.get_node(pointed_thing.under), player, pointed_thing)
            end
            return new_stack
 		end
 	end,
    on_secondary_use = rangefinder_mode_switch,
    on_place = rangefinder_mode_switch,
 	on_drop = function(itemstack, dropper, pos)
 	end,
})
minetest.register_alias("rangefinder", TOOL_NAME)

minetest.register_globalstep(function(dtime)
    local online_players = minetest.get_connected_players()

    if #online_players == 0 then
        return
    end

    for _,player in pairs(online_players) do
        local wield = player:get_wielded_item()
        if wield:get_name() == TOOL_NAME then
            if not hud:get(player, TOOL_NAME..":MRHUD:routine") then
                update_rf_mode_hud(player, wield)
            end
            local keys = player:get_player_control()
            if keys.zoom then
                show_zoom_hud(player)
            else
                hide_zoom_hud(player)
            end
            update_mode_hud_arrows(player, keys)
        else
            hud:remove(player)
            mrhud_mode_hud:remove(player)
        end
    end
end)

minetest.register_on_joinplayer(function(player)
    -- clear previously saved casts with rangefinder tool
    local inv = player:get_inventory()
    for list,data in pairs(inv:get_lists()) do
        for i,item in pairs(data) do
            if item:get_name() == TOOL_NAME then
                clear_saved_casts(player, item)
                inv:set_stack(list, i, item)
            end
        end
    end
end)


-- OLD FRAMEWORK

local finder_on = function(pos, facedir_param2, range)
    local meta = minetest.get_meta(pos)
    local block_pos = vector.new(pos)
    local beam_pos = vector.new(pos)
    local beam_direction = minetest.facedir_to_dir(facedir_param2)

    for i = 1, range + 1, 1 do
        beam_pos = vector.add(block_pos, vector.multiply(beam_direction, i))
        if minetest.get_node(beam_pos).name == "air" or minetest.get_node(beam_pos).name == "forestry_tools:rangefinder" then
            if i <= range then
                minetest.set_node(beam_pos, {name = "forestry_tools:rangefinder", param2 = facedir_param2})
                meta:set_string("infotext", "Distance: " .. tostring(i) .. "m")
                meta:set_int("range", i)
            else
                meta:set_string("infotext", "out of range")
                meta:set_int("range", range)
            end
        else
            break
        end
    end
end

local range_off = function(pos, facedir_param2, range)
    local meta = minetest.get_meta(pos)
    local block_pos = vector.new(pos)
    local beam_pos = vector.new(pos)
    local beam_direction = minetest.facedir_to_dir(facedir_param2)

    for i = range, 0, -1 do
        beam_pos = vector.add(block_pos, vector.multiply(beam_direction, i))
        if minetest.get_node(beam_pos).name == "forestry_tools:rangefinder" and minetest.get_node(beam_pos).param2 == facedir_param2 then
            minetest.set_node(beam_pos, {name="air"})
        end
    end
end

local range_check = function(pos, facedir_param2, range)
    local block_pos = vector.new(pos)
    local beam_pos = vector.new(pos)
    local beam_direction = minetest.facedir_to_dir(facedir_param2)
    local is_not_beam = false
    
    for i = 1, range + 1, 1 do
        beam_pos = vector.add(block_pos, vector.multiply(beam_direction, i))
        if minetest.get_node(beam_pos).name ~= "forestry_tools:rangefinder" and i <= range then
            is_not_beam = true
        elseif minetest.get_node(beam_pos).name == "air" and i <= laser_range then
            is_not_beam = true
        end
    end
    return is_not_beam
end
