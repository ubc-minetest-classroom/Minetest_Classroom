-- SECTIONS BORROWED FROM:
-- https://github.com/minetest-mods/nether/blob/master/portal_api.lua

portals.registered_portals = {}
portals.registered_portals_count = 0
portals.is_frame_node = {}

-- gives the colour values in portals_palette.png that are used by the wormhole colorfacedir
-- hardware colouring.
portals.portals_palette = {
    [0] = { r = 128, g = 0, b = 128, asString = "#800080" }, -- traditional/magenta
    [1] = { r = 0, g = 0, b = 0, asString = "#000000" }, -- black
    [2] = { r = 19, g = 19, b = 255, asString = "#1313FF" }, -- blue
    [3] = { r = 55, g = 168, b = 0, asString = "#37A800" }, -- green
    [4] = { r = 141, g = 237, b = 255, asString = "#8DEDFF" }, -- cyan
    [5] = { r = 221, g = 0, b = 0, asString = "#DD0000" }, -- red
    [6] = { r = 255, g = 240, b = 0, asString = "#FFF000" }, -- yellow
    [7] = { r = 255, g = 255, b = 255, asString = "#FFFFFF" }  -- white
}

local S = portals.get_translator
portals.portal_destination_not_found_message = S("Mysterious forces prevented you from opening that portal. Please try another location")

local facedir_up, facedir_north, facedir_south, facedir_east, facedir_west, facedir_down = 0, 4, 8, 12, 16, 20

local __ = { name = "air", prob = 0 }
local AA = { name = "air", prob = 255, force_place = true }
local PN = { name = "portals:portalstone", facedir = facedir_north + 0, prob = 255, force_place = true }
local PN2 = { name = "portals:portalstone", facedir = facedir_north + 1, prob = 255, force_place = true }
local PN3 = { name = "portals:portalstone", facedir = facedir_north + 2, prob = 255, force_place = true }
local PN4 = { name = "portals:portalstone", facedir = facedir_north + 3, prob = 255, force_place = true }
local PS = { name = "portals:portalstone", facedir = facedir_south, prob = 255, force_place = true }
local PE = { name = "portals:portalstone", facedir = facedir_east, prob = 255, force_place = true }
local PW = { name = "portals:portalstone", facedir = facedir_west, prob = 255, force_place = true }
local PU = { name = "portals:portalstone", facedir = facedir_up + 0, prob = 255, force_place = true }
local PU2 = { name = "portals:portalstone", facedir = facedir_up + 1, prob = 255, force_place = true }
local PU3 = { name = "portals:portalstone", facedir = facedir_up + 2, prob = 255, force_place = true }
local PU4 = { name = "portals:portalstone", facedir = facedir_up + 3, prob = 255, force_place = true }
local PD = { name = "portals:portalstone", facedir = facedir_down, prob = 255, force_place = true }

-- facedirNodeList is a list of node references which should have their facedir value copied into
-- param2 before placing a schematic. The facedir values will only be copied when the portal's frame
-- node has a paramtype2 of "facedir" or "colorfacedir".
-- Having schematics provide this list avoids needing to check every node in the schematic volume.
local facedirNodeList = { PN, PN2, PN3, PN4, PS, PE, PW, PU, PU2, PU3, PU4, PD }

portals.PortalShape_Traditional = {
    name = "Traditional",
    size = vector.new(4, 5, 1), -- size of the portal, and not necessarily the size of the schematic,
    -- which may clear area around the portal.
    is_horizontal = false, -- whether the wormhole is a vertical or horizontal surface

    -- returns the coords for minetest.place_schematic() that will place the schematic on the anchorPos
    get_schematicPos_from_anchorPos = function(anchorPos, orientation)
        assert(orientation, "no orientation passed")
        if orientation == 0 then
            return { x = anchorPos.x, y = anchorPos.y, z = anchorPos.z - 2 }
        else
            return { x = anchorPos.x - 2, y = anchorPos.y, z = anchorPos.z }
        end
    end,

    get_wormholePos_from_anchorPos = function(anchorPos, orientation)
        assert(orientation, "no orientation passed")
        if orientation == 0 then
            return { x = anchorPos.x + 1, y = anchorPos.y + 1, z = anchorPos.z }
        else
            return { x = anchorPos.x, y = anchorPos.y + 1, z = anchorPos.z + 1 }
        end
    end,

    get_anchorPos_from_wormholePos = function(wormholePos, orientation)
        assert(orientation, "no orientation passed")
        if orientation == 0 then
            return { x = wormholePos.x - 1, y = wormholePos.y - 1, z = wormholePos.z }
        else
            return { x = wormholePos.x, y = wormholePos.y - 1, z = wormholePos.z - 1 }
        end
    end,

    -- p1 and p2 are used to keep maps compatible with earlier versions of this mod.
    -- p1 is the bottom/west/south corner of the portal, and p2 is the opposite corner, together
    -- they define the bounding volume for the portal.
    get_p1_and_p2_from_anchorPos = function(self, anchorPos, orientation)
        assert(orientation, "no orientation passed")
        assert(self ~= nil and self.name == portals.PortalShape_Traditional.name, "Must pass self as first argument, or use shape:func() instead of shape.func()")
        local p1 = anchorPos -- PortalShape_Traditional puts the anchorPos at p1 for backwards&forwards compatibility
        local p2

        if orientation == 0 then
            p2 = { x = p1.x + self.size.x - 1, y = p1.y + self.size.y - 1, z = p1.z }
        else
            p2 = { x = p1.x, y = p1.y + self.size.y - 1, z = p1.z + self.size.x - 1 }
        end
        return p1, p2
    end,

    get_anchorPos_and_orientation_from_p1_and_p2 = function(p1, p2)
        if p1.z == p2.z then
            return p1, 0
        elseif p1.x == p2.x then
            return p1, 90
        else
            -- this KISS implementation will break you've made a 3D PortalShape definition
            minetest.log("error", "get_anchorPos_and_orientation_from_p1_and_p2 failed on  p1=" .. minetest.pos_to_string(p1) .. " p2=" .. minetest.pos_to_string(p2))
        end
    end,

    -- returns true if function was applied to all frame nodes
    apply_func_to_frame_nodes = function(anchorPos, orientation, func)
        -- a 4x5 portal is small enough that hardcoded positions is simpler that procedural code
        local shortCircuited
        if orientation == 0 then
            -- use short-circuiting of boolean evaluation to allow func() to cause an abort by returning true
            shortCircuited = func({ x = anchorPos.x + 0, y = anchorPos.y, z = anchorPos.z }) or
                    func({ x = anchorPos.x + 1, y = anchorPos.y, z = anchorPos.z }) or
                    func({ x = anchorPos.x + 2, y = anchorPos.y, z = anchorPos.z }) or
                    func({ x = anchorPos.x + 3, y = anchorPos.y, z = anchorPos.z }) or
                    func({ x = anchorPos.x + 0, y = anchorPos.y + 4, z = anchorPos.z }) or
                    func({ x = anchorPos.x + 1, y = anchorPos.y + 4, z = anchorPos.z }) or
                    func({ x = anchorPos.x + 2, y = anchorPos.y + 4, z = anchorPos.z }) or
                    func({ x = anchorPos.x + 3, y = anchorPos.y + 4, z = anchorPos.z }) or

                    func({ x = anchorPos.x, y = anchorPos.y + 1, z = anchorPos.z }) or
                    func({ x = anchorPos.x, y = anchorPos.y + 2, z = anchorPos.z }) or
                    func({ x = anchorPos.x, y = anchorPos.y + 3, z = anchorPos.z }) or
                    func({ x = anchorPos.x + 3, y = anchorPos.y + 1, z = anchorPos.z }) or
                    func({ x = anchorPos.x + 3, y = anchorPos.y + 2, z = anchorPos.z }) or
                    func({ x = anchorPos.x + 3, y = anchorPos.y + 3, z = anchorPos.z })
        else
            shortCircuited = func({ x = anchorPos.x, y = anchorPos.y, z = anchorPos.z + 0 }) or
                    func({ x = anchorPos.x, y = anchorPos.y, z = anchorPos.z + 1 }) or
                    func({ x = anchorPos.x, y = anchorPos.y, z = anchorPos.z + 2 }) or
                    func({ x = anchorPos.x, y = anchorPos.y, z = anchorPos.z + 3 }) or
                    func({ x = anchorPos.x, y = anchorPos.y + 4, z = anchorPos.z + 0 }) or
                    func({ x = anchorPos.x, y = anchorPos.y + 4, z = anchorPos.z + 1 }) or
                    func({ x = anchorPos.x, y = anchorPos.y + 4, z = anchorPos.z + 2 }) or
                    func({ x = anchorPos.x, y = anchorPos.y + 4, z = anchorPos.z + 3 }) or

                    func({ x = anchorPos.x, y = anchorPos.y + 1, z = anchorPos.z }) or
                    func({ x = anchorPos.x, y = anchorPos.y + 2, z = anchorPos.z }) or
                    func({ x = anchorPos.x, y = anchorPos.y + 3, z = anchorPos.z }) or
                    func({ x = anchorPos.x, y = anchorPos.y + 1, z = anchorPos.z + 3 }) or
                    func({ x = anchorPos.x, y = anchorPos.y + 2, z = anchorPos.z + 3 }) or
                    func({ x = anchorPos.x, y = anchorPos.y + 3, z = anchorPos.z + 3 })
        end
        return not shortCircuited
    end,

    -- Check for whether the portal is blocked in, and if so then provide a safe way
    -- on one side for the player to step out of the portal.
    -- If portal can appear in mid-air then can also check for that and add a platform.
    disable_portal_trap = function(anchorPos, orientation)
        assert(orientation, "no orientation passed")

        -- Not implemented yet. It may not need to be implemented because if you
        -- wait in a portal long enough you teleport again. So a trap portal would have to link
        -- to one of two blocked-in portals which link to each other - which is possible, but
        -- quite extreme.
    end,

    -- returns true if function was applied to all wormhole nodes
    apply_func_to_wormhole_nodes = function(anchorPos, orientation, func)
        local shortCircuited
        if orientation == 0 then
            local wormholePos = { x = anchorPos.x + 1, y = anchorPos.y + 1, z = anchorPos.z }
            -- use short-circuiting of boolean evaluation to allow func() to cause an abort by returning true
            shortCircuited = func({ x = wormholePos.x + 0, y = wormholePos.y + 0, z = wormholePos.z }) or
                    func({ x = wormholePos.x + 1, y = wormholePos.y + 0, z = wormholePos.z }) or
                    func({ x = wormholePos.x + 0, y = wormholePos.y + 1, z = wormholePos.z }) or
                    func({ x = wormholePos.x + 1, y = wormholePos.y + 1, z = wormholePos.z }) or
                    func({ x = wormholePos.x + 0, y = wormholePos.y + 2, z = wormholePos.z }) or
                    func({ x = wormholePos.x + 1, y = wormholePos.y + 2, z = wormholePos.z })
        else
            local wormholePos = { x = anchorPos.x, y = anchorPos.y + 1, z = anchorPos.z + 1 }
            shortCircuited = func({ x = wormholePos.x, y = wormholePos.y + 0, z = wormholePos.z + 0 }) or
                    func({ x = wormholePos.x, y = wormholePos.y + 0, z = wormholePos.z + 1 }) or
                    func({ x = wormholePos.x, y = wormholePos.y + 1, z = wormholePos.z + 0 }) or
                    func({ x = wormholePos.x, y = wormholePos.y + 1, z = wormholePos.z + 1 }) or
                    func({ x = wormholePos.x, y = wormholePos.y + 2, z = wormholePos.z + 0 }) or
                    func({ x = wormholePos.x, y = wormholePos.y + 2, z = wormholePos.z + 1 })
        end
        return not shortCircuited
    end,

    schematic = {
        size = { x = 4, y = 5, z = 5 },
        data = { -- note that data is upside down
            __, __, __, __,
            AA, AA, AA, AA,
            AA, AA, AA, AA,
            AA, AA, AA, AA,
            AA, AA, AA, AA,

            __, __, __, __,
            AA, AA, AA, AA,
            AA, AA, AA, AA,
            AA, AA, AA, AA,
            AA, AA, AA, AA,

            PN, PW, PE, PN2,
            PU, AA, AA, PU,
            PU, AA, AA, PU,
            PU, AA, AA, PU,
            PN4, PE, PW, PN3,

            __, __, __, __,
            AA, AA, AA, AA,
            AA, AA, AA, AA,
            AA, AA, AA, AA,
            AA, AA, AA, AA,

            __, __, __, __,
            AA, AA, AA, AA,
            AA, AA, AA, AA,
            AA, AA, AA, AA,
            AA, AA, AA, AA,
        },
        facedirNodes = facedirNodeList
    }
}

-- Portal implementation functions --
-- =============================== --

local ignition_item_name
local mod_storage = minetest.get_mod_storage()

local function get_timerPos_from_p1_and_p2(p1, p2)
    -- Pick a frame node for the portal's timer.
    --
    -- The timer event will need to know the portal definition, which can be determined by
    -- what the portal frame is made from, so the timer node should be on the frame.
    -- The timer event will also need to know its portal orientation, but unless someone
    -- makes a cubic portal shape, orientation can be determined from p1 and p2 in the node's
    -- metadata (frame nodes don't have orientation set in param2 like wormhole nodes do).
    --
    -- I'll pick the bottom center node of the portal.
    return {
        x = math.floor((p1.x + p2.x) / 2),
        y = p1.y,
        z = math.floor((p1.z + p2.z) / 2),
    }
end

-- orientation is the yaw rotation degrees passed to place_schematic: 0, 90, 180, or 270
-- color is a value from 0 to 7 corresponding to the color of pixels in portals_palette.png
-- portal_is_horizontal is a bool indicating whether the portal lies flat or stands vertically
local function get_colorfacedir_from_color_and_orientation(color, orientation, portal_is_horizontal)
    assert(orientation, "no orientation passed")

    local axis_direction, rotation
    local dir = math.floor((orientation % 360) / 90 + 0.5)

    -- if the portal is vertical then node axis direction will be +Y (up) and portal orientation
    -- will set the node's rotation.
    -- if the portal is horizontal then the node axis direction reflects the yaw orientation and
    -- the node's rotation will be whatever's needed to keep the texture horizontal (either 0 or 1)
    if portal_is_horizontal then
        if dir == 0 then
            axis_direction = 1
        end -- North
        if dir == 1 then
            axis_direction = 3
        end -- East
        if dir == 2 then
            axis_direction = 2
        end -- South
        if dir == 3 then
            axis_direction = 4
        end -- West
        rotation = math.floor(axis_direction / 2); -- a rotation is only needed if axis_direction is east or west
    else
        axis_direction = 0 -- 0 is up, or +Y
        rotation = dir
    end

    -- wormhole nodes have a paramtype2 of colorfacedir, which means the
    -- high 3 bits are palette, followed by 3 direction bits and 2 rotation bits.
    -- We set the palette bits and rotation
    return rotation + axis_direction * 4 + color * 32
end

local function get_orientation_from_colorfacedir(param2)

    local axis_direction = 0
    -- Strip off the top 6 bits to leave the 2 rotation bits, unfortunately MT lua has no bitwise '&'
    -- (high 3 bits are palette, followed by 3 direction bits then 2 rotation bits)
    if param2 >= 128 then
        param2 = param2 - 128
    end
    if param2 >= 64 then
        param2 = param2 - 64
    end
    if param2 >= 32 then
        param2 = param2 - 32
    end
    if param2 >= 16 then
        param2 = param2 - 16;
        axis_direction = axis_direction + 4
    end
    if param2 >= 8 then
        param2 = param2 - 8;
        axis_direction = axis_direction + 2
    end
    if param2 >= 4 then
        param2 = param2 - 4;
        axis_direction = axis_direction + 1
    end

    -- if the portal is vertical then node axis direction will be +Y (up) and portal orientation
    -- will set the node's rotation.
    -- if the portal is horizontal then the node axis direction reflects the yaw orientation and
    -- the node's rotation will be whatever's needed to keep the texture horizontal (either 0 or 1)
    if axis_direction == 0 or axis_direction == 5 then
        -- portal is vertical
        return param2 * 90
    else
        if axis_direction == 1 then
            return 0
        end
        if axis_direction == 3 then
            return 90
        end
        if axis_direction == 2 then
            return 180
        end
        if axis_direction == 4 then
            return 270
        end
    end
end

-- Combining frame_node_name, p1, and p2 will always be enough to uniquely identify a portal_definition
-- WITHOUT needing to inspect the world. register_portal() will enforce this.
-- This function does not require the portal to be in a loaded chunk.
-- Returns nil if no portal_definition matches the arguments
local function get_portal_definition(frame_node_name, p1, p2)

    local size = vector.add(vector.subtract(p2, p1), 1)
    local rotated_size = { x = size.z, y = size.y, z = size.x }

    for _, portal_def in pairs(portals.registered_portals) do
        if portal_def.frame_node_name == frame_node_name then
            if vector.equals(size, portal_def.shape.size) or vector.equals(rotated_size, portal_def.shape.size) then
                return portal_def
            end
        end
    end
    return nil
end

-- Returns a list of all portal_definitions with a frame made of frame_node_name.
-- If the list contains more than one item then routines like ignite_portal() will have to search twice
-- for a portal and take twice the CPU.
local function list_portal_definitions_for_frame_node(frame_node_name)
    local result = {}
    for _, portal_def in pairs(portals.registered_portals) do
        if portal_def.frame_node_name == frame_node_name then
            table.insert(result, portal_def)
        end
    end
    return result
end

-- Add portal information to mod storage, so new portals may find existing portals near the target location.
-- Do this whenever a portal is created or changes its ignition state
local function store_portal_location_info(portal_name, anchorPos, orientation, ignited)
    local key = minetest.pos_to_string(anchorPos) .. " is " .. portal_name
    -- debugf("Adding/updating portal in mod_storage: " .. key)
    mod_storage:set_string(
            key,
            minetest.serialize({ orientation = orientation, active = ignited })
    )
end

-- Remove portal information from mod storage.
-- Do this if a portal frame is destroyed such that it cannot be ignited anymore.
local function remove_portal_location_info(portal_name, anchorPos)
    local key = minetest.pos_to_string(anchorPos) .. " is " .. portal_name
    -- debugf("Removing portal from mod_storage: " .. key)
    mod_storage:set_string(key, "")
end

-- Returns a table of the nearest portals to anchorPos indexed by distance, based on mod_storage
-- data.
-- Only portals in the same realm as the anchorPos will be returned, even if y_factor is 0.
-- WARNING: Portals are not checked, and inactive portals especially may have been damaged without
-- being removed from the mod_storage data. Check these portals still exist before using them, and
-- invoke remove_portal_location_info() on any found to no longer exist.
--
-- A y_factor of 0 means y does not affect the distance_limit, a y_factor of 1 means y is included,
-- and a y_factor of 2 would squash the search-sphere by a factor of 2 on the y-axis, etc.
-- Pass a nil or negative distance_limit to indicate no distance limit
local function list_closest_portals(portal_definition, anchorPos, distance_limit, y_factor)

    local result = {}

    local isRealm = portal_definition.is_within_realm(anchorPos,portal_definition)
    if distance_limit == nil then
        distance_limit = -1
    end
    if y_factor == nil then
        y_factor = 1
    end

    for key, value in pairs(mod_storage:to_table().fields) do
        local closingBrace = key:find(")", 6, true)
        if closingBrace ~= nil then
            local found_anchorPos = minetest.string_to_pos(key:sub(0, closingBrace))
            if found_anchorPos ~= nil and portal_definition.is_within_realm(found_anchorPos,portal_definition) == isRealm then
                local found_name = key:sub(closingBrace + 5)
                if found_name == portal_definition.name then
                    local x = anchorPos.x - found_anchorPos.x
                    local y = anchorPos.y - found_anchorPos.y
                    local z = anchorPos.z - found_anchorPos.z
                    local distance = math.hypot(y * y_factor, math.hypot(x, z))
                    if distance <= distance_limit or distance_limit < 0 then
                        local info = minetest.deserialize(value) or {}
                        -- debugf("found %s listed at distance %.2f (within %.2f) from dest %s, found: %s orientation %s", found_name, distance, distance_limit, anchorPos, found_anchorPos, info.orientation)
                        info.anchorPos = found_anchorPos
                        info.distance = distance
                        result[distance] = info
                    end
                end
            end
        end
    end
    return result
end

-- WARNING - this is invoked by on_destruct, so you can't assume there's an accesible node at pos
-- Returns true if a portal was found to extinguish
function extinguish_portal(pos, node_name, frame_was_destroyed)

    -- debugf("extinguish_portal %s %s", pos, node_name)

    local meta = minetest.get_meta(pos)
    local p1 = minetest.string_to_pos(meta:get_string("p1"))
    local p2 = minetest.string_to_pos(meta:get_string("p2"))
    local target = minetest.string_to_pos(meta:get_string("target"))
    if p1 == nil or p2 == nil then
        -- debugf("    no active portal found to extinguish")
        return false
    end

    local portal_definition = get_portal_definition(node_name, p1, p2)
    if portal_definition == nil then
        minetest.log("error", "extinguish_portal() invoked on " .. node_name .. " but no registered portal is constructed from " .. node_name)
        return false -- no portal frames are made from this type of node
    end

    -- stop timer
    local timerPos = get_timerPos_from_p1_and_p2(p1, p2)
    minetest.get_node_timer(timerPos):stop()

    -- update the ignition state in the portal location info
    local anchorPos, orientation = portal_definition.shape.get_anchorPos_and_orientation_from_p1_and_p2(p1, p2)
    if frame_was_destroyed then
        remove_portal_location_info(portal_definition.name, anchorPos)
    else
        store_portal_location_info(portal_definition.name, anchorPos, orientation, false)
    end

    local frame_node_name = portal_definition.frame_node_name
    local wormhole_node_name = portal_definition.wormhole_node_name

    for x = p1.x, p2.x do
        for y = p1.y, p2.y do
            for z = p1.z, p2.z do
                local clearPos = { x = x, y = y, z = z }
                local nn = minetest.get_node(clearPos).name
                if nn == frame_node_name or nn == wormhole_node_name then
                    if nn == wormhole_node_name then
                        minetest.remove_node(clearPos)
                    end
                    local m = minetest.get_meta(clearPos)
                    m:set_string("p1", "")
                    m:set_string("p2", "")
                    m:set_string("target", "")
                    m:set_string("portal_type", "")
                end
            end
        end
    end

    if target ~= nil then
        -- debugf("    attempting to also extinguish target with wormholePos %s", target)
        extinguish_portal(target, node_name)
    end

    if portal_definition.on_extinguish ~= nil then
        portal_definition.on_extinguish(portal_definition, anchorPos, orientation)
    end

    return true
end

-- Note: will extinguish any portal using the same nodes that are being set
local function set_portal_metadata(portal_definition, anchorPos, orientation, destination_wormholePos, ignite)

    ignite = ignite or false;
    -- debugf("set_portal_metadata(ignite=%s) at %s orient %s, setting to target %s", ignite, anchorPos, orientation, destination_wormholePos)

    -- Portal position is stored in metadata as p1 and p2 to keep maps compatible with earlier versions of this mod.
    -- p1 is the bottom/west/south corner of the portal, and p2 is the opposite corner, together
    -- they define the bounding volume for the portal.
    local p1, p2 = portal_definition.shape:get_p1_and_p2_from_anchorPos(anchorPos, orientation)
    local p1_string, p2_string = minetest.pos_to_string(p1), minetest.pos_to_string(p2)
    local param2 = get_colorfacedir_from_color_and_orientation(portal_definition.wormhole_node_color, orientation, portal_definition.shape.is_horizontal)
    local mesecon_rules

    local update_aborted-- using closures to allow the updateFunc to return extra information - by setting this variable

    local updateFunc = function(pos)

        local meta = minetest.get_meta(pos)

        if ignite then
            local node_name = minetest.get_node(pos).name
            if node_name == "air" then
                minetest.set_node(pos, { name = portal_definition.wormhole_node_name, param2 = param2 })
            end

            local existing_p1 = meta:get_string("p1")
            if existing_p1 ~= "" then
                local existing_p2 = meta:get_string("p2")
                if existing_p1 ~= p1_string or existing_p2 ~= p2_string then
                    -- debugf("set_portal_metadata() found existing metadata from another portal: existing_p1 %s, existing_p2 %s, p1 %s, p2 %s, will extinguish existing portal...", existing_p1, existing_p2, p1_string, p2_string)
                    -- this node is already part of another portal, so extinguish that, because nodes only
                    -- contain a link in the metadata to one portal, and being part of two allows a slew of bugs
                    extinguish_portal(pos, node_name, false)

                    -- clear the metadata to avoid causing a loop if extinguish_portal() fails on this node (e.g. it only works on frame nodes)
                    meta:set_string("p1", nil)
                    meta:set_string("p2", nil)
                    meta:set_string("target", nil)
                    meta:set_string("portal_type", nil)

                    update_aborted = true
                    return true -- short-circuit the update
                end
            end
        end

        meta:set_string("p1", minetest.pos_to_string(p1))
        meta:set_string("p2", minetest.pos_to_string(p2))
        meta:set_string("target", minetest.pos_to_string(destination_wormholePos))
    end

    repeat
        update_aborted = false
        portal_definition.shape.apply_func_to_frame_nodes(anchorPos, orientation, updateFunc)
        portal_definition.shape.apply_func_to_wormhole_nodes(anchorPos, orientation, updateFunc)
    until not update_aborted

    local timerPos = get_timerPos_from_p1_and_p2(p1, p2)
    minetest.get_node_timer(timerPos):start(1)

    store_portal_location_info(portal_definition.name, anchorPos, orientation, true)
end

local function set_portal_metadata_and_ignite(portal_definition, anchorPos, orientation, destination_wormholePos)
    set_portal_metadata(portal_definition, anchorPos, orientation, destination_wormholePos, true)
end

-- this function returns two bools: portal found, portal is lit
local function is_portal_at_anchorPos(portal_definition, anchorPos, orientation, force_chunk_load)

    local nodes_are_valid   -- using closures to allow the check functions to return extra information - by setting this variable
    local portal_is_ignited -- using closures to allow the check functions to return extra information - by setting this variable

    local frame_node_name = portal_definition.frame_node_name
    local check_frame_Func = function(check_pos)
        local foundName = minetest.get_node(check_pos).name
        if foundName ~= frame_node_name then

            if force_chunk_load and foundName == "ignore" then
                -- area isn't loaded, force loading/emerge of check area
                minetest.get_voxel_manip():read_from_map(check_pos, check_pos)
                foundName = minetest.get_node(check_pos).name
                -- debugf("Forced loading of 'ignore' node at %s, got %s", check_pos, foundName)

                if foundName ~= frame_node_name then
                    nodes_are_valid = false
                    return true -- short-circuit the search
                end
            else
                nodes_are_valid = false
                return true -- short-circuit the search
            end
        end
    end

    local wormhole_node_name = portal_definition.wormhole_node_name
    local check_wormhole_Func = function(check_pos)
        local node_name = minetest.get_node(check_pos).name
        if node_name ~= wormhole_node_name then
            portal_is_ignited = false;
            if node_name ~= "air" then
                nodes_are_valid = false
                return true -- short-circuit the search
            end
        end
    end

    nodes_are_valid = true
    portal_is_ignited = true
    portal_definition.shape.apply_func_to_frame_nodes(anchorPos, orientation, check_frame_Func) -- check_frame_Func affects nodes_are_valid, portal_is_ignited

    if nodes_are_valid then
        -- a valid frame exists at anchorPos, check the wormhole is either ignited or unobstructed
        portal_definition.shape.apply_func_to_wormhole_nodes(anchorPos, orientation, check_wormhole_Func) -- check_wormhole_Func affects nodes_are_valid, portal_is_ignited
    end

    return nodes_are_valid, portal_is_ignited and nodes_are_valid -- returns two bools: portal was found, portal is lit
end

-- Checks pos, and if it's part of a portal or portal frame then three values are returned: anchorPos, orientation, is_ignited
-- where orientation is 0 or 90 (0 meaning a portal that faces north/south - i.e. obsidian running east/west)
local function is_within_portal_frame(portal_definition, pos)

    local width_minus_1 = portal_definition.shape.size.x - 1
    local height_minus_1 = portal_definition.shape.size.y - 1
    local depth_minus_1 = portal_definition.shape.size.z - 1

    for d = -depth_minus_1, depth_minus_1 do
        for w = -width_minus_1, width_minus_1 do
            for y = -height_minus_1, height_minus_1 do

                local testAnchorPos_x = { x = pos.x + w, y = pos.y + y, z = pos.z + d }
                local portal_found, portal_lit = is_portal_at_anchorPos(portal_definition, testAnchorPos_x, 0, true)

                if portal_found then
                    return testAnchorPos_x, 0, portal_lit
                else
                    -- try orthogonal orientation
                    local testForAnchorPos_z = { x = pos.x + d, y = pos.y + y, z = pos.z + w }
                    portal_found, portal_lit = is_portal_at_anchorPos(portal_definition, testForAnchorPos_z, 90, true)

                    if portal_found then
                        return testForAnchorPos_z, 90, portal_lit
                    end
                end
            end
        end
    end
end


-- sets param2 values in the schematic to match facedir values, or 0 if the portalframe-nodedef doesn't use facedir
local function set_schematic_param2(schematic_table, frame_node_name, frame_node_color)

    local paramtype2 = minetest.registered_nodes[frame_node_name].paramtype2
    local isFacedir = paramtype2 == "facedir" or paramtype2 == "colorfacedir"

    if schematic_table.facedirNodes ~= nil then
        for _, node in ipairs(schematic_table.facedirNodes) do
            if isFacedir and node.facedir ~= nil then
                -- frame_node_color can be nil
                local colorBits = (frame_node_color or math.floor((node.param2 or 0) / 32)) * 32
                node.param2 = node.facedir + colorBits
            else
                node.param2 = 0
            end
        end
    end
end

local function build_portal(portal_definition, anchorPos, orientation, destination_wormholePos)

    set_schematic_param2(portal_definition.shape.schematic, portal_definition.frame_node_name, portal_definition.frame_node_color)

    minetest.place_schematic(
            portal_definition.shape.get_schematicPos_from_anchorPos(anchorPos, orientation),
            portal_definition.shape.schematic,
            orientation,
            { -- node replacements
                ["portals:portalstone"] = portal_definition.frame_node_name,
            },
            true
    )
    -- set the param2 on wormhole nodes to ensure they are the right color
    local wormholeNode = {
        name = portal_definition.wormhole_node_name,
        param2 = get_colorfacedir_from_color_and_orientation(portal_definition.wormhole_node_color, orientation, portal_definition.shape.is_horizontal)
    }
    portal_definition.shape.apply_func_to_wormhole_nodes(
            anchorPos,
            orientation,
            function(pos)
                minetest.swap_node(pos, wormholeNode)
            end
    )

    -- debugf("Placed %s portal schematic at %s, orientation %s", portal_definition.name, portal_definition.shape.get_schematicPos_from_anchorPos(anchorPos, orientation), orientation)

    set_portal_metadata(portal_definition, anchorPos, orientation, destination_wormholePos)

    if portal_definition.on_created ~= nil then
        portal_definition.on_created(portal_definition, anchorPos, orientation)
    end
end


-- Sometimes after a portal is placed, concurrent mapgen routines overwrite it.
-- Make portals immortal for ~20 seconds after creation
local function remote_portal_checkup(elapsed, portal_definition, anchorPos, orientation, destination_wormholePos)

    -- debugf("portal checkup at %d seconds", elapsed)

    local wormholePos = portal_definition.shape.get_wormholePos_from_anchorPos(anchorPos, orientation)
    local wormhole_node = minetest.get_node_or_nil(wormholePos)

    local portalFound, portalLit = false, false
    if wormhole_node ~= nil and wormhole_node.name == portal_definition.wormhole_node_name then
        -- a wormhole node was there, but check the whole frame is intact
        portalFound, portalLit = is_portal_at_anchorPos(portal_definition, anchorPos, orientation, false)
    end

    if not portalFound or not portalLit then
        local message = "Newly created portal at " .. minetest.pos_to_string(anchorPos) .. " was overwritten. Attempting to recreate. Issue spotted after " .. elapsed .. " seconds"
        minetest.log("warning", message)
        -- debugf("!!! " .. message)

        -- A pre-existing portal frame wouldn't have been immediately overwritten, so no need to check for one, just place the portal.
        build_portal(portal_definition, anchorPos, orientation, destination_wormholePos)
    end

    if elapsed < 10 then
        -- stop checking after ~20 seconds
        local delay = elapsed * 2
        minetest.after(delay, remote_portal_checkup, elapsed + delay, portal_definition, anchorPos, orientation, destination_wormholePos)
    end
end


-- Used to find or build the remote twin after a portal is opened.
-- If a portal is found that is already lit then it will be extinguished first and its destination_wormholePos updated,
-- this is to enforce that portals only link together in mutual pairs. 
-- * suggested_wormholePos indicates where the portal should be built - note this not an anchorPos!
-- * suggested_orientation is the suggested schematic rotation to use if no useable portal is found at suggested_wormholePos:
--   0, 90, 180, 270 (0 meaning a portal that faces north/south - i.e. portalstone running east/west)
-- * destination_wormholePos is the wormholePos of the destination portal this one will be linked to.
--
-- Returns the final (anchorPos, orientation), as they may differ from the anchorPos and orientation that was
-- specified if an existing portal was already found there.
local function locate_or_build_portal(portal_definition, suggested_wormholePos, suggested_orientation, destination_wormholePos)

    -- debugf("locate_or_build_portal() called at wormholePos%s with suggested orient %s, targeted to %s", suggested_wormholePos, suggested_orientation, destination_wormholePos)

    local result_anchorPos;
    local result_orientation;

    -- Searching for an existing portal at wormholePos seems better than at anchorPos, though isn't important
    local found_anchorPos, found_orientation, is_ignited = is_within_portal_frame(portal_definition, suggested_wormholePos) -- can be optimized - check for portal at exactly suggested_wormholePos first

    if found_anchorPos ~= nil then
        -- A portal is already here, we don't have to build one, though we may need to ignite it
        result_anchorPos = found_anchorPos
        result_orientation = found_orientation

        if is_ignited then
            -- We're about to link to this portal, so if it's already linked to a different portal then
            -- extinguish it, to update the state of the about-to-be-orphaned portal.
            local result_target_str = minetest.get_meta(result_anchorPos):get_string("target")
            local result_target = minetest.string_to_pos(result_target_str)
            if result_target ~= nil and vector.equals(result_target, destination_wormholePos) then
                -- It already links back to the portal the player is teleporting from, so don't
                -- extinguish it or the player's portal will also extinguish.
                --debugf("    Build unnecessary: already a lit portal that links back here at %s, orientation %s", found_anchorPos, result_orientation)
            else
                --debugf("    Build unnecessary: already a lit portal at %s, orientation %s, linking to %s. Extinguishing...", found_anchorPos, result_orientation, result_target_str)
                extinguish_portal(found_anchorPos, portal_definition.frame_node_name, false)
            end
        else
            --debugf("    Build unnecessary: already an unlit portal at %s, orientation %s", found_anchorPos, result_orientation)
        end
        -- ignite the portal
        set_portal_metadata_and_ignite(portal_definition, result_anchorPos, result_orientation, destination_wormholePos)

    else
        result_orientation = suggested_orientation
        result_anchorPos = portal_definition.shape.get_anchorPos_from_wormholePos(suggested_wormholePos, result_orientation)
        build_portal(portal_definition, result_anchorPos, result_orientation, destination_wormholePos)
        -- make sure portal isn't overwritten by ongoing generation/emerge
        minetest.after(2, remote_portal_checkup, 2, portal_definition, result_anchorPos, result_orientation, destination_wormholePos)
    end
    return result_anchorPos, result_orientation
end


-- invoked when a player attempts to turn portalstone nodes into an open portal
-- player_name is optional, allowing a player to spawn a remote portal in their own protected area
-- ignition_node_name is optional
local function ignite_portal(ignition_pos, player_name, ignition_node_name)

    if ignition_node_name == nil then
        ignition_node_name = minetest.get_node(ignition_pos).name
    end
    -- debugf("IGNITE the %s at %s", ignition_node_name, ignition_pos)

    -- find which sort of portals are made from the node that was clicked on
    local portal_definition_list = list_portal_definitions_for_frame_node(ignition_node_name)

    for _, portal_definition in ipairs(portal_definition_list) do
        local continue = false -- WRT the for loop, since lua has no continue keyword

        -- check it was a portal frame that the player is trying to ignite
        local anchorPos, orientation, is_ignited = is_within_portal_frame(portal_definition, ignition_pos)
        if anchorPos == nil then
            -- debugf("No %s portal frame found at ", portal_definition.name, ignition_pos)
            continue = true -- no portal is here, but perhaps there's more than one portal type we need to search for
        elseif is_ignited then
            -- Found a portal, check its metadata and timer is healthy.
            local repair = false
            local meta = minetest.get_meta(ignition_pos)
            if meta ~= nil then
                local p1, p2, target = meta:get_string("p1"), meta:get_string("p2"), meta:get_string("target")
                if p1 == "" or p2 == "" or target == "" then
                    -- metadata is missing, the portal frame node must have been removed without calling
                    -- on_destruct - perhaps by an ABM, then replaced - presumably by a player.
                    -- allowing reigniting will repair the portal
                    -- debugf("Broken portal detected, allowing reignition/repair")
                    repair = true
                else
                    -- debugf("This portal links to %s. p1=%s p2=%s", meta:get_string("target"), meta:get_string("p1"), meta:get_string("p2"))

                    -- Check the portal's timer is running, and fix if it's not.
                    -- A portal's timer can stop running if the game is played without that portal type being
                    -- registered, e.g. enabling one of the example portals then later disabling it, then enabling it again.
                    -- (if this is a frequent problem, then change the value of "run_at_every_load" in the lbm)
                    local timer = minetest.get_node_timer(get_timerPos_from_p1_and_p2(minetest.string_to_pos(p1), minetest.string_to_pos(p2)))
                    if timer ~= nil and timer:get_timeout() == 0 then
                        -- debugf("Portal timer was not running: restarting the timer.")
                        timer:start(1)
                    end
                end
            end
            if not repair then
                return false
            end -- portal is already ignited (or timer has been fixed)
        end

        if continue == false then
            -- debugf("Found portal frame. Looked at %s, found at %s orientation %s", ignition_pos, anchorPos, orientation)

            local destination_anchorPos, destination_orientation
            if portal_definition.is_within_realm(ignition_pos,portal_definition) then
                destination_anchorPos, destination_orientation = portal_definition.find_surface_anchorPos(anchorPos, player_name or "")
            else
                destination_anchorPos, destination_orientation = portal_definition.find_realm_anchorPos(anchorPos, player_name or "")
            end
            if destination_orientation == nil then
                -- debugf("No destination_orientation given")
                destination_orientation = orientation
            end

            if destination_anchorPos == nil or destination_anchorPos.y == nil then
                -- destination_anchorPos.y was also checked for nil in case portal_definition.find_surface_anchorPos()
                -- had used portals.find_surface_target_y() and that had returned nil.
                -- debugf("No portal destination available here!")
                if (player_name or "") ~= "" then
                    minetest.chat_send_player(player_name, portals.portal_destination_not_found_message)
                end
                return false
            else
                local destination_wormholePos = portal_definition.shape.get_wormholePos_from_anchorPos(destination_anchorPos, destination_orientation)
                -- debugf("Destination set to %s", destination_anchorPos)

                -- ignition
                set_portal_metadata_and_ignite(portal_definition, anchorPos, orientation, destination_wormholePos)

                if portal_definition.on_ignite ~= nil then
                    portal_definition.on_ignite(portal_definition, anchorPos, orientation)
                end

                return true
            end
        end
    end
end


-- invoked when a player is standing in a portal
local function ensure_remote_portal_then_teleport(playerName, portal_definition, local_anchorPos, local_orientation, destination_wormholePos)

    local player = minetest.get_player_by_name(playerName)
    if player == nil then
        return
    end -- player quit the game while teleporting
    local playerPos = player:get_pos()
    if playerPos == nil then
        return
    end -- player quit the game while teleporting

    -- check player is still standing in a portal
    playerPos.y = playerPos.y + 0.1 -- Fix some glitches at -8000
    if minetest.get_node(playerPos).name ~= portal_definition.wormhole_node_name then
        return -- the player has moved out of the portal
    end

    -- debounce - check player is still standing in the *same* portal that called this function
    local meta = minetest.get_meta(playerPos)
    local local_p1, local_p2 = portal_definition.shape:get_p1_and_p2_from_anchorPos(local_anchorPos, local_orientation)
    local p1_at_playerPos = minetest.string_to_pos(meta:get_string("p1"))
    if p1_at_playerPos == nil or not vector.equals(local_p1, p1_at_playerPos) then
        -- debugf("the player already teleported from %s, and is now standing in a different portal - %s", local_anchorPos, meta:get_string("p1"))
        return -- the player already teleported, and is now standing in a different portal
    end

    local dest_wormhole_node = minetest.get_node_or_nil(destination_wormholePos)

    if dest_wormhole_node == nil then
        -- area not emerged yet, delay and retry
        -- debugf("ensure_remote_portal_then_teleport() could not find anything yet at %s", destination_wormholePos)
        minetest.after(1, ensure_remote_portal_then_teleport, playerName, portal_definition, local_anchorPos, local_orientation, destination_wormholePos)
    else
        local local_wormholePos = portal_definition.shape.get_wormholePos_from_anchorPos(local_anchorPos, local_orientation)

        if dest_wormhole_node.name == portal_definition.wormhole_node_name then
            -- portal exists

            local destination_orientation = get_orientation_from_colorfacedir(dest_wormhole_node.param2)
            local destination_anchorPos = portal_definition.shape.get_anchorPos_from_wormholePos(destination_wormholePos, destination_orientation)
            portal_definition.shape.disable_portal_trap(destination_anchorPos, destination_orientation)

            -- if the portal is already linked to a different portal then extinguish the other portal and
            -- update the target portal to point back at this one.
            local remoteMeta = minetest.get_meta(destination_wormholePos)
            local remoteTarget = minetest.string_to_pos(remoteMeta:get_string("target"))
            if remoteTarget == nil then
                -- debugf("Failed to test whether target portal links back to this one")
            elseif not vector.equals(remoteTarget, local_wormholePos) then
                -- debugf("Target portal is already linked, extinguishing then relighting to point back at this one")
                extinguish_portal(remoteTarget, portal_definition.frame_node_name, false)
                set_portal_metadata_and_ignite(
                        portal_definition,
                        destination_anchorPos,
                        destination_orientation,
                        local_wormholePos
                )
            end

            -- debugf("Teleporting player from wormholePos%s to wormholePos%s", local_wormholePos, destination_wormholePos)

            -- rotate the player if the destination portal is a different orientation
            local rotation_angle = math.rad(destination_orientation - local_orientation)
            local offset = vector.subtract(playerPos, local_wormholePos) -- preserve player's position in the portal
            local rotated_offset = { x = math.cos(rotation_angle) * offset.x - math.sin(rotation_angle) * offset.z, y = offset.y, z = math.sin(rotation_angle) * offset.x + math.cos(rotation_angle) * offset.z }
            local new_playerPos = vector.add(destination_wormholePos, rotated_offset)
            player:set_pos(new_playerPos)
            player:set_look_horizontal(player:get_look_horizontal() + rotation_angle)

            if portal_definition.on_player_teleported ~= nil then
                portal_definition.on_player_teleported(portal_definition, player, playerPos, new_playerPos)
            end
        else
            -- no wormhole node at destination - destination portal either needs to be built or ignited.
            -- Note: A very rare edge-case that is difficult to set up:
            --   If the destination portal is unlit and its frame shares a node with a lit portal that is linked to this
            --   portal (but has not been travelled through, thus not linking this portal back to it), then igniting
            --   the destination portal will extinguish the portal it's touching, which will extinguish this portal
            --   which will leave a confused player.
            -- debugf("ensure_remote_portal_then_teleport() saw %s at %s rather than a wormhole. Calling locate_or_build_portal()", dest_wormhole_node.name, destination_wormholePos)

            local new_dest_anchorPos, new_dest_orientation = locate_or_build_portal(portal_definition, destination_wormholePos, local_orientation, local_wormholePos)
            local new_dest_wormholePos = portal_definition.shape.get_wormholePos_from_anchorPos(new_dest_anchorPos, new_dest_orientation)

            if not vector.equals(destination_wormholePos, new_dest_wormholePos) then
                -- Update the local portal's target to match where the existing remote portal was found

                if minetest.get_meta(local_anchorPos):get_string("target") == "" then
                    -- The local portal has been extinguished!
                    -- Abort setting its metadata as that assumes it is active.
                    -- This shouldn't happen and may indicate a bug, I trap it incase when the destination
                    -- portal was found and extinguished, it somehow linked back to the local portal in a
                    -- misaligned fashion that wasn't recognized as being the local portal and caused the
                    -- local portal to also be extinguished.
                    local message = "Local portal at " .. minetest.pos_to_string(local_anchorPos) .. " was extinguished while linking to existing portal at " .. minetest.pos_to_string(new_dest_anchorPos)
                    minetest.log("error", message)
                    -- debugf("!ERROR! - " .. message)
                else
                    destination_wormholePos = new_dest_wormholePos
                    -- debugf("    updating target to where remote portal was found - %s", destination_wormholePos)

                    set_portal_metadata(
                            portal_definition,
                            local_anchorPos,
                            local_orientation,
                            destination_wormholePos
                    )
                end
            end
            minetest.after(0.1, ensure_remote_portal_then_teleport, playerName, portal_definition, local_anchorPos, local_orientation, destination_wormholePos)
        end
    end
end


-- run_wormhole() is invoked once per second per portal, handling teleportation and particle effects.
-- See get_timerPos_from_p1_and_p2() for an explanation of the timerPos location
function run_wormhole(timerPos, time_elapsed)

    local portal_definition -- will be used inside run_wormhole_node_func()

    local run_wormhole_node_func = function(pos)

        if math.random(2) == 1 then
            -- lets run only 3 particlespawners instead of 6 per portal
            minetest.add_particlespawner({
                amount = 16,
                time = 2,
                minpos = { x = pos.x - 0.25, y = pos.y - 0.25, z = pos.z - 0.25 },
                maxpos = { x = pos.x + 0.25, y = pos.y + 0.25, z = pos.z + 0.25 },
                minvel = { x = -0.8, y = -0.8, z = -0.8 },
                maxvel = { x = 0.8, y = 0.8, z = 0.8 },
                minacc = { x = 0, y = 0, z = 0 },
                maxacc = { x = 0, y = 0, z = 0 },
                minexptime = 0.5,
                maxexptime = 1.7,
                minsize = 0.5 * portal_definition.particle_texture_scale,
                maxsize = 1.5 * portal_definition.particle_texture_scale,
                collisiondetection = false,
                texture = portal_definition.particle_texture_colored,
                animation = portal_definition.particle_texture_animation,
                glow = 5
            })
        end

        for _, obj in ipairs(minetest.get_objects_inside_radius(pos, 1)) do
            if obj:is_player() then
                local meta = minetest.get_meta(pos)
                local destination_wormholePos = minetest.string_to_pos(meta:get_string("target"))
                local local_p1 = minetest.string_to_pos(meta:get_string("p1"))
                local local_p2 = minetest.string_to_pos(meta:get_string("p2"))
                if destination_wormholePos ~= nil and local_p1 ~= nil and local_p2 ~= nil then

                    -- force emerge of target area
                    minetest.get_voxel_manip():read_from_map(destination_wormholePos, destination_wormholePos) -- force load
                    if minetest.get_node_or_nil(destination_wormholePos) == nil then
                        minetest.emerge_area(vector.subtract(destination_wormholePos, 4), vector.add(destination_wormholePos, 4))
                    end

                    local local_anchorPos, local_orientation = portal_definition.shape.get_anchorPos_and_orientation_from_p1_and_p2(local_p1, local_p2)
                    local playerName = obj:get_player_name()
                    minetest.after(
                            3, -- hopefully target area is emerged in 3 seconds
                            function()
                                ensure_remote_portal_then_teleport(
                                        playerName,
                                        portal_definition,
                                        local_anchorPos,
                                        local_orientation,
                                        destination_wormholePos
                                )
                            end
                    )
                end
            end
        end
    end

    local p1, p2, portal_name
    local meta = minetest.get_meta(timerPos)
    if meta ~= nil then
        p1 = minetest.string_to_pos(meta:get_string("p1"))
        p2 = minetest.string_to_pos(meta:get_string("p2"))
        portal_name = minetest.string_to_pos(meta:get_string("portal_type"))
    end
    if p1 ~= nil and p2 ~= nil then
        -- figure out the portal shape so we know where the wormhole nodes will be located
        local frame_node_name
        if portal_name ~= nil and portals.registered_portals[portal_name] ~= nil then
            portal_definition = portals.registered_portals[portal_name]
        else
            frame_node_name = minetest.get_node(timerPos).name -- timerPos should be a frame node if the shape is traditionalPortalShape
            portal_definition = get_portal_definition(frame_node_name, p1, p2)
        end

        if portal_definition == nil then
            minetest.log("error", "No portal with a \"" .. frame_node_name .. "\" frame is registered. run_wormhole" .. minetest.pos_to_string(timerPos) .. " was invoked but that location contains \"" .. frame_node_name .. "\"")
        else
            local anchorPos, orientation = portal_definition.shape.get_anchorPos_and_orientation_from_p1_and_p2(p1, p2)
            portal_definition.shape.apply_func_to_wormhole_nodes(anchorPos, orientation, run_wormhole_node_func)

            if portal_definition.on_run_wormhole ~= nil then
                portal_definition.on_run_wormhole(portal_definition, anchorPos, orientation)
            end

            local wormholePos = portal_definition.shape.get_wormholePos_from_anchorPos(anchorPos, orientation)
        end
    end
end

function register_frame_node(frame_node_name)

    -- copy the existing node definition
    local node_def = minetest.registered_nodes[frame_node_name]
    local extended_node_def = {}
    for key, value in pairs(node_def) do
        extended_node_def[key] = value
    end

    extended_node_def.replaced_by_portalapi = {} -- allows chaining or restoration of original functions, if necessary

    -- add portal portal functionality

    extended_node_def.replaced_by_portalapi.on_destruct = extended_node_def.on_destruct
    extended_node_def.on_destruct = function(pos)
        -- debugf("portal frame material: destruct")
        extinguish_portal(pos, frame_node_name, true)
    end
    extended_node_def.replaced_by_portalapi.on_blast = extended_node_def.on_blast
    extended_node_def.on_blast = function(pos, intensity)
        -- debugf("portal frame material: blast")
        extinguish_portal(pos, frame_node_name, extended_node_def.replaced_by_portalapi.on_blast == nil)
        if extended_node_def.replaced_by_portalapi.on_blast ~= nil then
            extended_node_def.replaced_by_portalapi.on_blast(pos, intensity)
        else
            minetest.remove_node(pos)
        end
    end
    extended_node_def.replaced_by_portalapi.on_timer = extended_node_def.on_timer
    extended_node_def.on_timer = function(pos, elapsed)
        run_wormhole(pos, elapsed)
        return true
    end

    -- replace the node with the new extended definition
    minetest.register_node(":" .. frame_node_name, extended_node_def)
end

function unregister_frame_node(frame_node_name)

    -- copy the existing node definition
    local node = minetest.registered_nodes[frame_node_name]
    local restored_node_def = {}
    for key, value in pairs(node) do
        restored_node_def[key] = value
    end

    -- remove portal portal functionality
    restored_node_def.on_destruct = nil
    restored_node_def.on_timer = nil
    restored_node_def.replaced_by_portalapi = nil

    if node.replaced_by_portalapi ~= nil then
        for key, value in pairs(node.replaced_by_portalapi) do
            restored_node_def[key] = value
        end
    end

    -- replace the node with the restored definition
    minetest.register_node(":" .. frame_node_name, restored_node_def)
end

-- check for mistakes people might make in custom shape definitions
function test_shapedef_is_valid(shape_defintion)
    assert(shape_defintion ~= nil, "shape definition cannot be nil")
    assert(shape_defintion.name ~= nil, "shape definition must have a name")

    local result = true

    local origin = vector.new()
    local p1, p2 = shape_defintion:get_p1_and_p2_from_anchorPos(origin, 0)
    assert(vector.equals(shape_defintion.size, vector.add(vector.subtract(p2, p1), 1)), "p1 and p2 of shape definition '" .. shape_defintion.name .. "' don't match shapeDef.size")

    -- assert(shape_defintion.diagram_image ~= nil and shape_defintion.diagram_image.image ~= nil,  "Shape definition '" .. shape_defintion.name .. "' does not provide an image for Help/Book of Portals")
    -- assert(shape_defintion.diagram_image.width > 0 and shape_defintion.diagram_image.height > 0, "Shape definition '" .. shape_defintion.name .. "' does not provide the size of the image for Help/Book of Portals")

    -- todo

    return result
end


-- check for mistakes people might make in portal definitions
function test_portaldef_is_valid(portal_definition)

    local result = test_shapedef_is_valid(portal_definition.shape)

    assert(portal_definition.wormhole_node_color >= 0 and portal_definition.wormhole_node_color < 8, "portaldef.wormhole_node_color must be between 0 and 7 (inclusive)")
    assert(portal_definition.is_within_realm ~= nil, "portaldef.is_within_realm() must be implemented")
    assert(portal_definition.find_realm_anchorPos ~= nil, "portaldef.find_realm_anchorPos() must be implemented")

    if portal_definition.frame_node_color ~= nil then
        assert(portal_definition.frame_node_color >= 0 and portal_definition.frame_node_color < 8, "portal_definition.frame_node_color must be between 0 and 7 (inclusive)")
    end
    -- todo

    return result
end

-- Portal API functions --
-- ==================== --


-- the fallback defaults for wormhole nodedefs
local wormhole_nodedef_default = {
    description = S("Portal wormhole"),
    tiles = {
        "portals_transparent.png",
        "portals_transparent.png",
        "portals_transparent.png",
        "portals_transparent.png",
        {
            name = "portals_portal.png",
            animation = {
                type = "vertical_frames",
                aspect_w = 16,
                aspect_h = 16,
                length = 0.9,
            },
        },
        {
            name = "portals_portal.png",
            animation = {
                type = "vertical_frames",
                aspect_w = 16,
                aspect_h = 16,
                length = 0.9,
            },
        },
    },
    drawtype = "nodebox",
    paramtype = "light",
    paramtype2 = "colorfacedir",
    palette = "portals_palette.png",
    post_effect_color = {
        -- post_effect_color can't be changed dynamically in Minetest like the portal colour is.
        -- If you need a different post_effect_color then use register_wormhole_node() to create
        -- another wormhole node with the right post_effect_color and set it as the wormhole_node_name
        -- in your portaldef.
        -- Hopefully this colour is close enough to magenta to work with the traditional magenta
        -- portals, close enough to red to work for a red portal, and also close enough to red to
        -- work with blue & cyan portals - since blue portals are sometimes portrayed as being red
        -- from the opposite side / from the inside.
        a = 160, r = 128, g = 0, b = 80
    },
    sunlight_propagates = true,
    use_texture_alpha = minetest.features.use_texture_alpha_string_modes
            and "blend" or true,
    walkable = false,
    diggable = false,
    pointable = false,
    buildable_to = false,
    is_ground_content = false,
    drop = "",
    light_source = 5,
    node_box = {
        type = "fixed",
        fixed = {
            { -0.5, -0.5, -0.1, 0.5, 0.5, 0.1 },
        },
    },
    groups = { not_in_creative_inventory = 1 }
}


-- Call only at load time
function portals.register_wormhole_node(name, nodedef)
    assert(name ~= nil, "Unable to register wormhole node: Name is nil")
    assert(nodedef ~= nil, "Unable to register wormhole node ''" .. name .. "'': nodedef is nil")

    for key, value in pairs(wormhole_nodedef_default) do
        if nodedef[key] == nil then
            nodedef[key] = value
        end
    end
    minetest.register_node(name, nodedef)
end


-- The fallback defaults for registered portaldef tables
local portaldef_default = {
    title = S("Untitled portal"),
    shape = portals.PortalShape_Traditional,
    wormhole_node_name = "portals:portal",
    wormhole_node_color = 0,
    frame_node_name = "portals:portalstone",
    particle_texture = "portals_particle.png",
    particle_texture_animation = nil,
    particle_texture_scale = 1
}

function portals.register_portal(name, portaldef)

    assert(name ~= nil, "Unable to register portal: Name is nil")
    assert(portaldef ~= nil, "Unable to register portal ''" .. name .. "'': portaldef is nil")
    if portals.registered_portals[name] ~= nil then
        minetest.log("error", "Unable to register portal: '" .. name .. "' is already in use")
        return false;
    end

    portaldef.name = name
    portaldef.mod_name = minetest.get_current_modname() or "<mod name not recorded>"

    -- use portaldef_default for any values missing from portaldef or portaldef.sounds
    if portaldef.sounds ~= nil then
        setmetatable(portaldef.sounds, { __index = portaldef_default.sounds })
    end
    setmetatable(portaldef, { __index = portaldef_default })

    if portaldef.particle_color == nil then
        -- default the particle colours to be the same as the wormhole colour
        assert(portaldef.wormhole_node_color >= 0 and portaldef.wormhole_node_color < 8, "portaldef.wormhole_node_color must be between 0 and 7 (inclusive)")
        portaldef.particle_color = portals.portals_palette[portaldef.wormhole_node_color].asString
    end
    if portaldef.particle_texture_colored == nil then
        -- Combine the particle texture with the particle color unless a particle_texture_colored was specified.
        if type(portaldef.particle_texture) == "table" and portaldef.particle_texture.animation ~= nil then
            portaldef.particle_texture_colored = portaldef.particle_texture.name .. "^[colorize:" .. portaldef.particle_color .. ":alpha"
            portaldef.particle_texture_animation = portaldef.particle_texture.animation
            portaldef.particle_texture_scale = portaldef.particle_texture.scale or 1
        else
            portaldef.particle_texture_colored = portaldef.particle_texture .. "^[colorize:" .. portaldef.particle_color .. ":alpha"
        end
    end

    if portaldef.find_surface_anchorPos == nil then
        -- default to using find_surface_target_y()
        portaldef.find_surface_anchorPos = function(pos, player_name)

            local destination_pos = { x = pos.x, y = 0, z = pos.z }
            local existing_portal_location, existing_portal_orientation = portals.find_nearest_working_portal(name, destination_pos, 10, 0) -- a y_factor of 0 makes the search ignore the altitude of the portals (as long as they are outside the realm)
            if existing_portal_location ~= nil then
                return existing_portal_location, existing_portal_orientation
            else
                destination_pos.y = portals.find_surface_target_y(destination_pos.x, destination_pos.z, name, player_name)
                return destination_pos
            end
        end
    end

    if test_portaldef_is_valid(portaldef) then

        -- check whether the portal definition clashes with anyone else's portal
        local p1, p2 = portaldef.shape:get_p1_and_p2_from_anchorPos(vector.new(), 0)
        local existing_portaldef = get_portal_definition(portaldef.frame_node_name, p1, p2)
        if existing_portaldef ~= nil then
            minetest.log("error",
                    portaldef.mod_name .. " tried to register a portal '" .. portaldef.name .. "' made of " .. portaldef.frame_node_name ..
                            ", but it is the same material and shape as the portal '" .. existing_portaldef.name .. "' already registered by " .. existing_portaldef.mod_name ..
                            ". Edit the values one of those mods uses in its call to portals.register_portal() if you wish to resolve this clash.")
        else
            -- the new portaldef is good
            portals.registered_portals[portaldef.name] = portaldef

            -- Update registered_portals_count
            local portalCount = 0
            for _ in pairs(portals.registered_portals) do
                portalCount = portalCount + 1
            end
            portals.registered_portals_count = portalCount

            -- create_book_of_portals()

            if not portals.is_frame_node[portaldef.frame_node_name] then
                -- add portal functions to the nodedef being used for the portal frame
                register_frame_node(portaldef.frame_node_name)
                portals.is_frame_node[portaldef.frame_node_name] = true
            end

            return true
        end
    end

    return false
end

function portals.unregister_portal(name)

    assert(name ~= nil, "Cannot unregister portal: Name is nil")

    local portaldef = portals.registered_portals[name]
    local result = portaldef ~= nil

    if portaldef ~= nil then
        portals.registered_portals[name] = nil

        local portals_still_using_frame_node = list_portal_definitions_for_frame_node(portaldef.frame_node_name)
        if next(portals_still_using_frame_node) == nil then
            -- no portals are using this frame node any more
            unregister_frame_node(portaldef.frame_node_name)
            portals.is_frame_node[portaldef.frame_node_name] = nil
        end
    end

    return result
end

function portals.register_portal_ignition_item(item_name)

    minetest.override_item(item_name, {
        on_place = function(stack, placer, pt)
            local done = false
            if pt.under and portals.is_frame_node[minetest.get_node(pt.under).name] then
                done = ignite_portal(pt.under, placer:get_player_name())
                if done and not minetest.settings:get_bool("creative_mode") then
                    stack:take_item()
                end
            end

            return stack
        end,
    })

    ignition_item_name = item_name
end


-- use this when determining where to spawn a portal, to avoid overwriting player builds
-- It checks the area for any nodes that aren't ground or trees.
-- player_name is optional, allowing a player to spawn a remote portal in their own protected areas.
-- (Water also fails this test, unless it is unemerged)
function portals.volume_is_natural_and_unprotected(minp, maxp, player_name)

    local c_air = minetest.get_content_id("air")
    local c_ignore = minetest.get_content_id("ignore")

    local vm = minetest.get_voxel_manip()
    local emin, emax = vm:read_from_map(minp, maxp)
    local area = VoxelArea:new({ MinEdge = emin, MaxEdge = emax })
    local data = vm:get_data()

    for z = minp.z, maxp.z do
        for y = minp.y, maxp.y do
            local vi = area:index(minp.x, y, z)
            for x = minp.x, maxp.x do
                local id = data[vi] -- Existing node
                -- if id == nil then debugf("nil block at index " .. vi) end
                if id ~= c_air and id ~= c_ignore and id ~= nil then
                    -- checked for common natural or not emerged
                    local name = minetest.get_name_from_content_id(id)
                    local nodedef = minetest.registered_nodes[name]
                    if nodedef and not nodedef.is_ground_content then
                        -- trees are natural but not "ground content"
                        local node_groups = nodedef.groups
                        if node_groups == nil or (node_groups.tree == nil and node_groups.leaves == nil and node_groups.leafdecay == nil) then
                            -- debugf("volume_is_natural_and_unprotected() found unnatural node %s", name)
                            return false
                        end
                    end
                end
                vi = vi + 1
            end
        end
    end

    if minetest.is_area_protected(minp, maxp, player_name or "") then
        -- debugf("Volume is protected against player '%s', %s-%s", player_name, minp, maxp)
        return false;
    end

    -- debugf("Volume is natural and unprotected for player '%s', %s-%s", player_name, minp, maxp)
    return true
end


-- Gets the volume that may be altered if a portal is placed at the anchor_pos
-- orientation is optional, but specifying it will reduce the volume returned
-- portal_name is optional, but specifying it will reduce the volume returned
-- returns minp, maxp
function portals.get_schematic_volume(anchor_pos, orientation, portal_name)

    if orientation == nil then
        -- Return a volume large enough for any orientation
        local minp0, maxp0 = portals.get_schematic_volume(anchor_pos, 0, portal_name)
        local minp1, maxp1 = portals.get_schematic_volume(anchor_pos, 1, portal_name)

        -- ToDo: If an asymmetric portal is used with an anchor not at the center of the
        -- schematic then we will also need to check orientations 3 and 4.
        -- (The currently existing portal-shapes are not affected)
        return
        { x = math.min(minp0.x, minp1.x), y = math.min(minp0.y, minp1.y), z = math.min(minp0.z, minp1.z) },
        { x = math.max(maxp0.x, maxp1.x), y = math.max(maxp0.y, maxp1.y), z = math.max(maxp0.z, maxp1.z) }
    end

    -- Assume the largest possible portal shape unless we know it's a smaller one.
    local shape_defintion = portals.PortalShape_Circular
    if portal_name ~= nil and portals.registered_portals[portal_name] ~= nil then
        shape_defintion = portals.registered_portals[portal_name].shape
    end

    local size = shape_defintion.schematic.size
    local minp = shape_defintion.get_schematicPos_from_anchorPos(anchor_pos, orientation);
    local maxp

    if (orientation % 2) == 0 then
        maxp = { x = minp.x + size.x - 1, y = minp.y + size.y - 1, z = minp.z + size.z - 1 }
    else
        maxp = { x = minp.x + size.z - 1, y = minp.y + size.y - 1, z = minp.z + size.x - 1 }
    end
    return minp, maxp
end


-- Can be used when implementing custom find_surface_anchorPos() functions
-- portal_name is optional, providing it allows existing portals on the surface to be reused, and
-- a potentially smaller volume to be checked by volume_is_natural_and_unprotected().
-- player_name is optional, allowing a player to spawn a remote portal in their own protected areas.
function portals.find_surface_target_y(target_x, target_z, portal_name, player_name)

    assert(target_x ~= nil and target_z ~= nil, "Arguments `target_x` and `target_z` cannot be nil when calling find_surface_target_y()")

    -- default to starting the search at -16 (probably underground) if we don't know the
    -- surface, like paramat's original code from before get_spawn_level() was available:
    -- https://github.com/minetest-mods/nether/issues/5#issuecomment-506983676
    local start_y = -16

    -- try to spawn on surface first
    if minetest.get_spawn_level ~= nil then
        -- older versions of Minetest don't have this
        local surface_level = minetest.get_spawn_level(target_x, target_z)
        if surface_level ~= nil then
            -- test this since get_spawn_level() can return nil over water or steep/high terrain

            -- get_spawn_level() tends to err on the side of caution and spawns the player a
            -- block higher than the ground level. The implementation is mapgen specific
            -- and -2 seems to be the right correction for v6, v5, carpathian, valleys, and flat,
            -- but v7 only needs -1.
            -- Perhaps this was not always the case, and -2 may be too much in older versions
            -- of minetest, but half-buried portals are perferable to floating ones, and they
            -- will clear a suitable hole around themselves.
            if minetest.get_mapgen_setting("mg_name") == "v7" then
                surface_level = surface_level - 1
            else
                surface_level = surface_level - 2
            end
            start_y = surface_level
        end
    end

    local minp_schem, maxp_schem = portals.get_schematic_volume({ x = target_x, y = 0, z = target_z }, nil, portal_name)
    local minp = { x = minp_schem.x, y = 0, z = minp_schem.z }
    local maxp = { x = maxp_schem.x, y = 0, z = maxp_schem.z }

    -- Starting searchstep at -16 and making it larger by 2 after each step gives a 20-step search range down to -646:
    -- 0, -16, -34, -54, -76, -100, -126, -154, -184, -216, -250, -286, -324, -364, -406, -450, -496, -544, -594, -646
    local searchstep = -16;

    local y = start_y
    while y > start_y - 650 do
        -- Check volume for non-natural nodes
        minp.y = minp_schem.y + y
        maxp.y = maxp_schem.y + y
        if portals.volume_is_natural_and_unprotected(minp, maxp, player_name) then
            return y
        elseif portal_name ~= nil and portals.registered_portals[portal_name] ~= nil then
            -- players have built here - don't grief.
            -- but reigniting existing portals in portal rooms is fine - desirable even.
            local anchorPos, orientation, is_ignited = is_within_portal_frame(portals.registered_portals[portal_name], { x = target_x, y = y, z = target_z })
            if anchorPos ~= nil then
                -- debugf("volume_is_natural_and_unprotected check failed, but a portal frame is here %s, so this is still a good target y level", anchorPos)
                return y
            end
        end
        y = y + searchstep
        searchstep = searchstep - 2
    end

    return nil -- Portal ignition failure. Possibly due to a large protected area.
end


-- Returns the anchorPos, orientation of the nearest portal, or nil.
-- A y_factor of 0 means y does not affect the distance_limit, a y_factor of 1 means y is included,
-- and a y_factor of 2 would squash the search-sphere by a factor of 2 on the y-axis, etc.
-- Pass a negative distance_limit to indicate no distance limit
function portals.find_nearest_working_portal(portal_name, anchorPos, distance_limit, y_factor)

    local portal_definition = portals.registered_portals[portal_name]
    assert(portal_definition ~= nil, "find_nearest_working_portal() called with portal_name '" .. portal_name .. "', but no portal is registered with that name.")
    assert(anchorPos ~= nil, "Argument `anchorPos` cannot be nil when calling find_nearest_working_portal()")

    local contenders = list_closest_portals(portal_definition, anchorPos, distance_limit, y_factor)

    -- sort by distance
    local dist_list = {}
    for dist, _ in pairs(contenders) do
        table.insert(dist_list, dist)
    end
    table.sort(dist_list)

    for _, dist in ipairs(dist_list) do
        local portal_info = contenders[dist]
        -- debugf("checking portal from mod_storage at %s orientation %s", portal_info.anchorPos, portal_info.orientation)

        -- the mod_storage list of portals is unreliable - e.g. it won't know if inactive portals have been
        -- destroyed, so check the portal is still there
        local portalFound, portalIsActive = is_portal_at_anchorPos(portal_definition, portal_info.anchorPos, portal_info.orientation, true)

        if portalFound then
            return portal_info.anchorPos, portal_info.orientation
        else
            -- debugf("Portal wasn't found, removing portal from mod_storage at %s orientation %s",
            -- 	portal_info.anchorPos, portal_info.orientation)
            -- The portal at that location must have been destroyed
            remove_portal_location_info(portal_name, portal_info.anchorPos)
        end
    end
    return nil
end