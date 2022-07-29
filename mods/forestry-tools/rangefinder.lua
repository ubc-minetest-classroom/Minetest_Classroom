--[[ TODO
-- Add calculation/cast outputs to HUD instead of chat
-- Auto-reset?
-- Implement alternate left-click actions (?)
-- Implement AZ and ML-AZ modes
  -- AZ = reading at current point (basically, compass)
  -- ML-AZ = direction from cast 1 to cast 2 (angle between N and ray vector)
]]

--[[ CURRENT CONTROL SCHEME
-- L-CLICK               = take measurement/clear
-- L-CLICK + AUX         = clear previous measurement
-- L-CLICK + AUX + SNEAK = clear all measurements

-- R-CLICK               = cycle (forwards)
-- R-CLICK + AUX         = cycle (reverse)
-- R-CLICK + SNEAK       = cycle routine (forwards)
-- R-CLICK + AUX + SNEAK = cycle routine (reverse)

-- L-CLICK + SNEAK       = open measurement settings (IN CONSIDERATION)
]]

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
local MRHUD_SPACER = 0.1
local MRHUD_ARROW_DEFAULTS = {
    up = "forestry_tools_rf_arrow_up.png",
    down = "forestry_tools_rf_arrow_up.png^[transformFY"
}
local TOOL_NAME = "forestry_tools:rangefinder"

forestry_tools.rangefinder = {}
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

-- Sets the internal index number for the rangefinder's current routine to the given number
local function set_routine(meta, routine)
    meta:set_int("routine", tonumber(routine))
end

-- Sets the internal index number for the rangefinder's current mode to the given number
local function set_mode(meta, routine)
    meta:set_int("mode", tonumber(routine))
end

-- Replaces player's current copy of itemstack with the given copy of itemstack
local function save_item_meta(player, itemstack)
    local stack_name = itemstack:get_name()
    if player:get_wielded_item():get_name() == stack_name then
        player:set_wielded_item(itemstack)
    else
        local inv = player:get_inventory()
        for lname,list in pairs(inv:get_lists()) do
            for i,item in pairs(list) do
                if item:get_name() == stack_name then
                    inv:set_stack(lname, i, itemstack)
                    return
                end
            end
        end
    end
end

-- Constrains val to the open domain defined by [min, max]
local function constrain(min, val, max)
    return math.max(min, math.min(max, val))
end

-- Returns the precision that should be used for rounding the rangefinder's output based on the least precise rangefinder measurement recorded
local function get_precision(meta)
    local prec_table = minetest.deserialize(meta:get("precs") or minetest.serialize({}))
    local precision = 1
    local precision_map = {
        [true] = 1,
        [false] = 0,
        ["angle"] = 1
    }
    for i,prec in ipairs(prec_table) do
        precision = precision * precision_map[prec]
    end
    return precision
end

-- Returns the precision for a single cast, as above
local function get_single_precision(meta, cast_num)
    local prec_table = minetest.deserialize(meta:get("precs") or minetest.serialize({}))
    local precision_map = {
        [true] = 1,
        [false] = 0,
        ["angle"] = 0
    }
    return precision_map[prec_table[cast_num]]
end

-- Stores values into the rangefinder's display metadata, allowing them to be displayed the next time the rangefinder is selected
local function store_display_meta(meta, output, desc)
    meta:set_string("display_output", output)
    meta:set_string("display_desc", desc)
end

-- Updates the main rangefinder display's text, changing it to the given output text and description
local function update_display(player, meta, output, desc)
    local function get_output_def(col, offset, z_index)
        return {
            hud_elem_type = "text",
            position = {x = 0.5, y = 0.08},
            alignment = {x = 0, y = 0},
            offset = offset or {x = 0, y = 0},
            color = col or 0xFFFFFF,
            scale = {x = 100, y = 100},
            text = output or "-----",
            text_scale = 8,
            style = 5,
            z_index = z_index or 4
        }
    end
    local function get_desc_def(col, offset, z_index)
        return {
            hud_elem_type = "text",
            position = {x = 0.5, y = 0.16},
            alignment = {x = 0, y = 0},
            offset = offset or {x = 0, y = 0},
            color = col or 0xFFFFFF,
            scale = {x = 100, y = 100},
            text = desc or "awaiting cast",
            text_scale = 2,
            style = 4,
            z_index = z_index or 2
        }
    end

    if not hud:get(player, TOOL_NAME..":output") then
        hud:add(player, TOOL_NAME..":output", get_output_def())
        hud:add(player, TOOL_NAME..":output_desc", get_desc_def())
        hud:add(player, TOOL_NAME..":output_shadow", get_output_def(0x000000, {x = 3, y = 3}, 3))
        hud:add(player, TOOL_NAME..":output_desc_shadow", get_desc_def(0x000000, {x = 2, y = 2}, 1))
    else
        hud:change(player, TOOL_NAME..":output", get_output_def())
        hud:change(player, TOOL_NAME..":output_desc", get_desc_def())
        hud:change(player, TOOL_NAME..":output_shadow", get_output_def(0x000000, {x = 3, y = 3}, 3))
        hud:change(player, TOOL_NAME..":output_desc_shadow", get_desc_def(0x000000, {x = 2, y = 2}, 1))
    end
    store_display_meta(meta, output, desc)
end

local function clear_display_callback(player)
    local pname = player:get_player_name()
    if forestry_tools["rangefinder"][pname] then
        forestry_tools["rangefinder"][pname]["cancel"]()
        forestry_tools["rangefinder"][pname] = nil
    end
end

-- Clears all the logged casts from the rangefinder's metadata
local function clear_saved_casts(player, itemstack, log_if_empty)
    clear_display_callback(player)

    local meta = itemstack:get_meta()
    local count = 0
    meta:set_string("casts", "")
    local mark_table = minetest.deserialize(meta:get("marks") or minetest.serialize({}))
    for i,mark in pairs(mark_table) do
        local mark_id = (type(mark) == "table" and mark.id) or mark -- compatibility
        if hud:get(player, mark_id) then
            hud:remove(player, mark_id)
        end
        count = count + 1
    end
    meta:set_string("marks", "")
    meta:set_string("precs", "")

    if count > 0 then
        update_display(player, meta)
        minetest.chat_send_player(player:get_player_name(), "Rangefinder memory cleared, ready to start new measurement")
    elseif log_if_empty then
        minetest.chat_send_player(player:get_player_name(), "Rangefinder memory empty, no measurements cleared")
    end
    return itemstack
end

-- Clears the last logged cast from the rangefinder's metadata
local function undo_last_cast(player, itemstack)
    clear_display_callback(player)

    local meta = itemstack:get_meta()
    local cast_table = minetest.deserialize(meta:get("casts") or minetest.serialize({}))
    local mark_table = minetest.deserialize(meta:get("marks") or minetest.serialize({}))
    local prec_table = minetest.deserialize(meta:get("precs") or minetest.serialize({}))

    if #cast_table > 0 and #mark_table > 0 and #prec_table > 0 then
        table.remove(cast_table)
        meta:set_string("casts", minetest.serialize(cast_table))
        table.remove(prec_table)
        meta:set_string("precs", minetest.serialize(prec_table))

        local mark = table.remove(mark_table)
        local mark_id = (type(mark) == "table" and mark.id) or mark -- compatibility
        if hud:get(player, mark_id) then
            hud:remove(player, mark_id)
        end
        meta:set_string("marks", minetest.serialize(mark_table))

        update_display(player, meta)
        minetest.chat_send_player(player:get_player_name(), "Previous cast cleared from rangefinder memory")
    else
        minetest.chat_send_player(player:get_player_name(), "Rangefinder memory empty, no measurements cleared")
    end

    return itemstack
end

-- Adds a cast market to the world
local function add_cast_marker(player, pos, is_angle)
    local marker_id = hud:add(player, nil, {
        hud_elem_type = "image_waypoint",
        world_pos = pos,
        text = is_angle and "forestry_tools_rf_anglemarker.png" or "forestry_tools_rf_marker.png",
        scale = {x = 1.5, y = 1.5},
        z_index = is_angle and -301 or -300,
        alignment = {x = 0, y = 0}
    })
    return {id = marker_id, pos = pos, is_angle = is_angle}
end

-- Returns the first valid block hit by the ray, and whether the hit is accurate or not
local function get_first_valid_hit(ray, dir)
    local rng = PcgRandom(os.clock())

    local hit = ray:next()
    while hit do
        if hit.type == "object" then
            return hit, true -- always hit objects
        elseif hit.type == "node" then
            local node = minetest.get_node(hit.under)
            local node_def = minetest.registered_nodes[node.name]
            if node_def then
                if node_def.drawtype == "plantlike" or node_def.drawtype == "plantlike_rooted" then
                    -- plantlike: 70% chance to detect normally, 30% chance to skip
                    local rng_gen = rng:next(1, 100)
                    if rng_gen > 30 then
                        return hit, false
                    end
                elseif node_def.groups["leaves"] or node_def.groups["sapling"] then
                    -- defined as plant: 5% chance to detect normally, 85% chance to detect with random noise, 10% chance to skip
                    local rng_gen = rng:next(1, 100)
                    if rng_gen > 95 then
                        return hit, false
                    elseif rng_gen > 10 then
                        local noise_mod = rng:next(0, 65535) / 65535
                        local noise_vector = vector.multiply(dir, noise_mod)
                        local hit_point = hit.intersection_point

                        local noisy_hit = table.copy(hit)
                        noisy_hit.intersection_point = {x = hit_point.x + noise_vector.x, y = hit_point.y + noise_vector.y, z = hit_point.z + noise_vector.z}
                        return noisy_hit, false
                    end
                else
                    -- not a plant: valid
                    return hit, true
                end
            end
        end
        hit = ray:next()
    end
    return nil
end

-- Casts a ray and logs where it first hit, if it hit an object/node in range
local function track_raycast_hit(player, itemstack)
    local meta = itemstack:get_meta()
    if meta then
        -- log hit in rangefinder
        local cast_table = minetest.deserialize(meta:get("casts") or minetest.serialize({}))
        local mark_table = minetest.deserialize(meta:get("marks") or minetest.serialize({}))
        local prec_table = minetest.deserialize(meta:get("precs") or minetest.serialize({}))
        local routine = get_routine(meta)

        if #cast_table >= ROUTINES[routine]["casts"] then
            -- clear hits
            return clear_saved_casts(player, itemstack), nil, nil
        end

        local player_pos = vector.offset(player:get_pos(), 0, player:get_properties().eye_height, 0)
        local ray = minetest.raycast(player_pos, vector.add(player_pos, vector.multiply(player:get_look_dir(), RAY_RANGE)))
        local cast_point, first_hit, is_precise = ray:next(), get_first_valid_hit(ray, player:get_look_dir())

        if not first_hit then
            -- no objects/nodes within range, note failed hit
            minetest.chat_send_player(player:get_player_name(), "Nothing detected within a 500m range, measurement not tracked")
            return itemstack, nil, nil
        end

        local dir = vector.direction(cast_point.intersection_point, first_hit.intersection_point)
        local dist = vector.distance(cast_point.intersection_point, first_hit.intersection_point)
        local is_angle = routine == 2 and #mark_table ~= 0

        -- display hit on screen + log info in rangefinder
        table.insert(cast_table, {dir = dir, dist = dist})
        meta:set_string("casts", minetest.serialize(cast_table))
        table.insert(mark_table, add_cast_marker(player, first_hit.intersection_point, is_angle))
        meta:set_string("marks", minetest.serialize(mark_table))
        table.insert(prec_table, is_precise or (is_angle and "angle"))
        meta:set_string("precs", minetest.serialize(prec_table))

        local table_length = math.min(#cast_table, #mark_table, #prec_table)
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

-- Creates the background for the rangefinder's routine/mode display
local function create_mode_hud_background(player)
    if not hud:get(player, TOOL_NAME..":MRHUD:routine_bg") then
        local shift = (math.abs(MRHUD_BG_SCALE.y) + math.abs(SUB_BG_SCALE.y)) / 200
        hud:add(player, TOOL_NAME..":MRHUD:routine_bg", {
            hud_elem_type = "image",
            position = MRHUD_POS,
            alignment = {x = 0, y = 0},
            offset = MRHUD_OFFSET,
            scale = MRHUD_BG_SCALE,
            text = "forestry_tools_pixel.png^[multiply:#000000^[opacity:127",
            z_index = -2,
        })
        hud:add(player, TOOL_NAME..":MRHUD:routine_bg_u", {
            hud_elem_type = "image",
            position = {x = MRHUD_POS.x, y = MRHUD_POS.y - shift},
            alignment = {x = 0, y = 0},
            offset = MRHUD_OFFSET,
            scale = SUB_BG_SCALE,
            text = "forestry_tools_pixel.png^[multiply:#39403b^[opacity:127",
            z_index = -3,
        })
        hud:add(player, TOOL_NAME..":MRHUD:routine_bg_l", {
            hud_elem_type = "image",
            position = {x = MRHUD_POS.x, y = MRHUD_POS.y + shift},
            alignment = {x = 0, y = 0},
            offset = MRHUD_OFFSET,
            scale = SUB_BG_SCALE,
            text = "forestry_tools_pixel.png^[multiply:#39403b^[opacity:127",
            z_index = -3,
        })
    end
end

-- Creates the arrows for the rangefinder's routine/mode display
local function create_mode_hud_arrows(player)
    if not hud:get(player, TOOL_NAME..":MRHUD:arrow_mu") then
        local arrow_table = {
            [TOOL_NAME..":MRHUD:arrow_mu"] = {
                hud_elem_type = "image",
                position = {x = MRHUD_POS.x, y = MRHUD_POS.y},
                alignment = {x = 0, y = -1},
                offset = MRHUD_OFFSET,
                scale = {x = -0.75, y = -0.75},
                text = MRHUD_ARROW_DEFAULTS.up,
                z_index = -1
            },
            [TOOL_NAME..":MRHUD:arrow_md"] = {
                hud_elem_type = "image",
                position = {x = MRHUD_POS.x, y = MRHUD_POS.y},
                alignment = {x = 0, y = 1},
                offset = MRHUD_OFFSET,
                scale = {x = -0.75, y = -0.75},
                text = MRHUD_ARROW_DEFAULTS.down,
                z_index = -1
            },

            [TOOL_NAME..":MRHUD:arrow_ru"] = {
                hud_elem_type = "image",
                position = {x = MRHUD_POS.x, y = MRHUD_POS.y - math.abs(MRHUD_BG_SCALE.y / 200)},
                alignment = {x = 0, y = 0},
                offset = MRHUD_OFFSET,
                scale = {x = -0.75, y = -0.75},
                text = MRHUD_ARROW_DEFAULTS.up,
                z_index = -1
            },
            [TOOL_NAME..":MRHUD:arrow_rd"] = {
                hud_elem_type = "image",
                position = {x = MRHUD_POS.x, y = MRHUD_POS.y + math.abs(MRHUD_BG_SCALE.y / 200)},
                alignment = {x = 0, y = 0},
                offset = MRHUD_OFFSET,
                scale = {x = -0.75, y = -0.75},
                text = MRHUD_ARROW_DEFAULTS.down,
                z_index = -1
            }
        }
        for elem,def in pairs(arrow_table) do
            hud:add(player, elem, def)
        end
        --minetest.log(minetest.serialize(hud:get(player, TOOL_NAME..":MRHUD:arrow_mu")))
    end
end

-- Moves the routine/mode display's arrows to the given position, offsetting them by the given amount
local function move_mode_hud_arrows(player, position, offset)
    -- create arrows if they do not already exist
    create_mode_hud_arrows(player)
    local def_table = {
        mu = hud:get(player, TOOL_NAME..":MRHUD:arrow_mu").def,
        md = hud:get(player, TOOL_NAME..":MRHUD:arrow_md").def,
    }

    def_table.mu.position = {x = MRHUD_POS.x + position.x, y = MRHUD_POS.y + position.y - offset}
    def_table.md.position = {x = MRHUD_POS.x + position.x, y = MRHUD_POS.y + position.y + offset}
    hud:change(player, TOOL_NAME..":MRHUD:arrow_mu", def_table.mu)
    hud:change(player, TOOL_NAME..":MRHUD:arrow_md", def_table.md)
end

-- Creates the arrows indicating the current mode change direction for the rangefinder's mode display
local function update_mode_hud_arrows(player, itemstack)
    local keys = player:get_player_control()
    local meta = itemstack:get_meta()
    local routine, mode = get_routine(meta), get_mode(meta)
    
    -- create arrows if they do not already exist
    create_mode_hud_arrows(player)
    local def_table = {
        [TOOL_NAME..":MRHUD:arrow_mu"] = hud:get(player, TOOL_NAME..":MRHUD:arrow_mu").def,
        [TOOL_NAME..":MRHUD:arrow_md"] = hud:get(player, TOOL_NAME..":MRHUD:arrow_md").def,
        [TOOL_NAME..":MRHUD:arrow_ru"] = hud:get(player, TOOL_NAME..":MRHUD:arrow_ru").def,
        [TOOL_NAME..":MRHUD:arrow_rd"] = hud:get(player, TOOL_NAME..":MRHUD:arrow_rd").def,
    }

    for elem,def in pairs(def_table) do
        local pos, dir = string.sub(elem, -2, -2), string.sub(elem, -1, -1)
        local text = (dir == "u" and MRHUD_ARROW_DEFAULTS.up) or MRHUD_ARROW_DEFAULTS.down

        if pos == "m" then
            if dir == "u" then
                text = text..(keys.aux1 and "^[multiply:#f2fcf9" or "^[multiply:#a9a9a9")
                def.scale = (keys.aux1 and {x = -0.85, y = -0.85}) or {x = -0.6, y = -0.6}
            elseif dir == "d" then
                text = text..(not keys.aux1 and "^[multiply:#f2fcf9" or "^[multiply:#a9a9a9")
                def.scale = (not keys.aux1 and {x = -0.85, y = -0.85}) or {x = -0.6, y = -0.6}
            end
            def.text = text..((keys.sneak or #ROUTINES[routine]["modes"] == 1) and "^[opacity:0" or "")
        elseif pos == "r" then
            if dir == "u" then
                def.text = text..(keys.aux1 and "^[multiply:#f2fcf9" or "^[multiply:#a9a9a9")..((keys.sneak or mode == 1) and "" or "^[opacity:0")
                def.scale = (keys.aux1 and {x = -1.25, y = -1.25}) or {x = -0.75, y = -0.75}
            elseif dir == "d" then
                def.text = text..(not keys.aux1 and "^[multiply:#f2fcf9" or "^[multiply:#a9a9a9")..((keys.sneak or mode == #ROUTINES[routine]["modes"]) and "" or "^[opacity:0")
                def.scale = (not keys.aux1 and {x = -1.25, y = -1.25}) or {x = -0.75, y = -0.75}
            end
        end
        hud:change(player, elem, def)
    end
end

-- Creates the mode display area for the rangefinder's routine/mode HUD
local function update_mode_hud_modes(player, itemstack)
    local meta = itemstack:get_meta()
    local routine, mode = get_routine(meta), get_mode(meta)
    local mode_count = #ROUTINES[routine]["modes"]

    -- clear mode hud to prevent element overlap
    mrhud_mode_hud:remove(player)
    if mode_count ~= 1 then
        local scale = {x = -5, y = (math.abs(MRHUD_BG_SCALE.y) - MRHUD_SPACER * (mode_count - 1)) / -mode_count}
        local shift_x = (math.abs(MRHUD_BG_SCALE.x / 2) + math.abs(scale.x / 2) + MRHUD_SPACER) / 100
        local initial_y = (math.abs(scale.y) - math.abs(MRHUD_BG_SCALE.y))/200

        for i,mode_data in ipairs(ROUTINES[routine]["modes"]) do
            local offset_y = initial_y + ((i - 1)*(math.abs(scale.y) + MRHUD_SPACER)/100)
            mrhud_mode_hud:add(player, TOOL_NAME..":MRHUD:mode_"..i, {
                hud_elem_type = "image",
                position = {x = MRHUD_POS.x + shift_x, y = MRHUD_POS.y + offset_y},
                alignment = {x = 0, y = 0},
                offset = MRHUD_OFFSET,
                scale = scale,
                text = (i == mode and "forestry_tools_pixel.png^[multiply:#7a968b^[opacity:159") or "forestry_tools_pixel.png^[multiply:#39403b^[opacity:127",
                z_index = -3,
            })
            mode_hud_text_abstract(player, mrhud_mode_hud, "add", TOOL_NAME..":MRHUD:mode_"..i.."_text", mode_data["key"], {x = shift_x, y = offset_y}, (i == mode and 0xffffff) or 0xd0d0d0, (i == mode and 2) or 1, 5)
        end

        move_mode_hud_arrows(player, {x = shift_x, y = initial_y + ((mode - 1)*(math.abs(scale.y) + MRHUD_SPACER)/100) + MRHUD_SPACER/200}, math.abs(scale.y / 200))
    end
    update_mode_hud_arrows(player, itemstack)
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
        mode_hud_text_abstract(player, hud, (mode_hud_exists and "change") or "add", TOOL_NAME..":MRHUD:routine_prev", ROUTINES[surround.prev]["key"], {y = -sub_shift}, 0xcacfcd, 2, 4)
        mode_hud_text_abstract(player, hud, (mode_hud_exists and "change") or "add", TOOL_NAME..":MRHUD:routine_next", ROUTINES[surround.next]["key"], {y = sub_shift}, 0xcacfcd, 2, 4)
        
        update_mode_hud_modes(player, itemstack)
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
        local decim = places > 0 and string.sub(num_string, -places) or ""
        return decim ~= "" and (whole ~= "" and whole or "0").."."..decim or (whole ~= "" and whole or "0")
    end
end

-- Returns the length of the side of a triangle opposite angle theta, given theta and the other two side lengths
local function cosine_law(a, b, theta)
    return math.sqrt(a^2 + b^2 - 2*a*b*math.cos(theta))
end

-- Calculates the final output for the rangefinder to display
local function rangefinder_calc(meta, pmeta)
    local casts = minetest.deserialize(meta:get_string("casts"))
    local routine, mode = get_routine(meta), get_mode(meta)
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
                local slope_dir = casts[1]["dir"]
                local declination = pmeta:get_int("declination") -- magnetic declination value from compass
                local yaw = vector.rotate(vector.new(slope_dir.x, 0, slope_dir.z), vector.new(0, math.rad(declination), 0))
                local theta = math.deg(vector.angle(vector.new(0, 0, 1), yaw))
                return math.sign(yaw.x) == -1 and (360 - theta) or theta
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
                local vect_a = vector.multiply(casts[1]["dir"], casts[1]["dist"])
                local vect_b = vector.multiply(casts[2]["dir"], casts[2]["dist"])
                local slope_vect = vector.subtract(vect_b, vect_a)
                local declination = pmeta:get_int("declination") -- magnetic declination value from compass
                local yaw = vector.rotate(vector.new(slope_vect.x, 0, slope_vect.z), vector.new(0, math.rad(declination), 0))
                local theta = math.deg(vector.angle(vector.new(0, 0, 1), yaw))
                return math.sign(yaw.x) == -1 and (360 - theta) or theta
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

    set_mode(meta, new_mode)
    set_routine(meta, new_routine)
    
    update_rf_mode_hud(player, itemstack)
    if cur_routine ~= new_routine then
        clear_saved_casts(player, itemstack)
    else
        minetest.after(0.1, function(player, meta, routine, mode, itemstack)
            local result = rangefinder_calc(meta, player:get_meta())
            if result then
                local round_res = round_to_decim_places(result, get_precision(meta), true)
                clear_display_callback(player)
                update_display(player, meta, round_res..ROUTINES[new_routine]["modes"][new_mode]["unit"], "final measurement")
                save_item_meta(player, itemstack)
            end
        end, player, meta, new_routine, new_mode, itemstack)
    end
    return itemstack
end

minetest.register_tool(TOOL_NAME, {
 	description = "Rangefinder",
 	inventory_image = "rangefinder.jpg",
 	-- Left-click the tool activate function
 	on_use = function(itemstack, player, pointed_thing)
        local pname = player:get_player_name()
 		-- Check for shout privileges
 		if forestry_tools.check_perm(player) then
            local keys = player:get_player_control()

            if keys.aux1 then
                if keys.sneak then
                    -- reset measurements
                    return clear_saved_casts(player, itemstack, true)
                else
                    -- undo last measurement
                    return undo_last_cast(player, itemstack)
                end
            else
                -- record measurement
                local new_stack, cast_num, cast_complete = track_raycast_hit(player, itemstack)
                if new_stack then
                    local meta = new_stack:get_meta()
                    
                    -- log cast distance
                    if cast_num then
                        minetest.after(0.1, function(player, meta, cast_num)
                            local casts = minetest.deserialize(meta:get_string("casts"))
                            if casts[cast_num] then
                                local cast_dist = round_to_decim_places(casts[cast_num]["dist"], get_single_precision(meta, cast_num), true)
                                clear_display_callback(player)
                                update_display(player, meta, cast_dist.."m", "cast "..cast_num)
                            end
                        end, player, meta, cast_num)
                    end
                    -- perform and log calculation
                    if cast_complete then
                        minetest.after(0.2, function(player, meta, itemstack)
                            local result = rangefinder_calc(meta, player:get_meta())
                            local routine, mode = get_routine(meta), get_mode(meta)
                            if result then
                                local round_res = round_to_decim_places(result, get_precision(meta), true)
                                if ROUTINES[routine]["casts"] == 1 then
                                    clear_display_callback(player)
                                    update_display(player, meta, round_res..ROUTINES[routine]["modes"][mode]["unit"], "final measurement")
                                else
                                    -- store callback ID in case another mode is selected
                                    local output = round_res..ROUTINES[routine]["modes"][mode]["unit"]
                                    store_display_meta(meta, output, "final measurement")
                                    save_item_meta(player, itemstack)
                                    forestry_tools["rangefinder"][pname] = minetest.after(1.2, update_display, player, meta, output, "final measurement")
                                end
                            end
                        end, player, meta, new_stack)
                    end
                end
    
                -- Register a node punch
                if pointed_thing.under then
                    minetest.node_punch(pointed_thing.under, minetest.get_node(pointed_thing.under), player, pointed_thing)
                end
                return new_stack
            end
 		end
 	end,
    on_secondary_use = rangefinder_mode_switch,
    on_place = rangefinder_mode_switch,
 	on_drop = function(itemstack, dropper, pos)
 	end,
})

minetest.register_alias("rangefinder", TOOL_NAME)
if minetest.get_modpath("mc_toolhandler") then
	mc_toolhandler.register_tool_manager(TOOL_NAME, {privs = forestry_tools.priv_table})
end

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
                local meta = wield:get_meta()
                local mark_table = minetest.deserialize(meta:get("marks") or minetest.serialize({}))
                for i,mark in ipairs(mark_table) do
                    if type(mark) == "table" then
                        mark_table[i] = add_cast_marker(player, mark.pos, mark.is_angle)
                    end
                end
                meta:set_string("marks", minetest.serialize(mark_table))
                update_display(player, meta, meta:get("display_output"), meta:get("display_desc"))
                player:set_wielded_item(wield)
            end
            local keys = player:get_player_control()
            if keys.zoom then
                show_zoom_hud(player)
            else
                hide_zoom_hud(player)
            end
            update_mode_hud_arrows(player, wield)
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
                local meta = item:get_meta()
                if not ROUTINES[get_routine(meta)] then
                    set_routine(meta, 1)
                end
                if not ROUTINES[get_routine(meta)]["modes"][get_mode(meta)] then
                    set_mode(meta, 1)
                end
                inv:set_stack(list, i, item)
            end
        end
    end
end)


-- OLD FRAMEWORK

--[[local finder_on = function(pos, facedir_param2, range)
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
end]]
