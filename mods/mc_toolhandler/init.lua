mc_toolhandler = {
    path = minetest.get_modpath("mc_toolhandler"),
    reg_tools = {}, 
    reg_groups = {},
    reg_group_tools = {},
    next_group = 1,
    default_inv = (minetest.get_modpath("mc_toolmenu") ~= nil and mc_toolmenu.tool_inv) or "main"
}

local function get_tools_in_group(group)
    local output = {}
    for tool, tool_group in pairs(mc_toolhandler.reg_group_tools) do
        if group == tool_group then
            table.insert(output, tool)
        end
    end
    return output
end

-- Returns name of list item is in, if it is in player's inventory
local function get_player_item_location(player, itemstack)
    local inv = player:get_inventory()
    return mc_helpers.getInventoryItemLocation(inv, itemstack)
end

-- Returns name of list and index of first item in group in player's inventory, if an item in group is in player's inventory
local function get_player_group_location(player, group)
    local inv = player:get_inventory()
    for list,data in pairs(inv:get_lists()) do
        for _,tool in pairs(get_tools_in_group(group)) do
            if inv:contains_item(list, ItemStack(tool)) then
                return list, tool
            end
        end
    end
    return nil
end

-- Returns true if player has 2 of more of itemstack, false otherwise
local function player_has_item_copies(player, itemstack)
    local inv = player:get_inventory()
    local stack_2 = ItemStack(itemstack)
    stack_2:set_count(2)
    local count = 0
    for list,data in pairs(inv:get_lists()) do
        if inv:contains_item(list, stack_2) then
            return true
        elseif inv:contains_item(list, itemstack) then
            count = count + 1
            if count >= 2 then
                return true
            end
        end
    end
    return false
end

-- Returns true if player has 2 of more items in group, false otherwise
local function player_has_group_copies(player, group)
    local inv = player:get_inventory()
    local count = 0
    for _,tool in pairs(get_tools_in_group(group)) do
        local stack = ItemStack(tool)
        local stack_2 = ItemStack(tool)
        stack_2:set_count(2)
        for list,data in pairs(inv:get_lists()) do
            if inv:contains_item(list, stack_2) then
                return true
            elseif inv:contains_item(list, stack) then
                count = count + 1
                if count >= 2 then
                    return true
                end
            end
        end
    end
end

-- Removes all copies of itemstack from player's inventory, except the one at i_0 in list_0
local function remove_item_copies_except(player, itemstack, i_0, list_0)
    local inv = player:get_inventory()
    for list,data in pairs(inv:get_lists()) do
        if inv:contains_item(list, itemstack) then
            for i,_ in pairs(data) do
                if inv:get_stack(list, i):get_name() == itemstack:get_name() and (i ~= i_0 or list ~= list_0) then
                    inv:set_stack(list, i, ItemStack(nil))
                end
            end
        end
    end
end

-- Removes all items in group from player's inventory, except the one at i_0 in list_0
local function remove_group_copies_except(player, group, i_0, list_0)
    local inv = player:get_inventory()
    for list,data in pairs(inv:get_lists()) do
        for i,item in pairs(data) do
            if mc_toolhandler.reg_group_tools[item:get_name()] == group and (i ~= i_0 or list ~= list_0) then
                inv:set_stack(list, i, ItemStack(nil))
            end
        end
    end
end

--- @public
--- Registers `tool` to be managed by `mc_toolhandler`
--- @param tool Name of tool to be managed
--- @param options Table of tool options
--- @see README.md > API > mc_toolhandler.register_tool_manager
function mc_toolhandler.register_tool_manager(tool, options)
    if not tool then
        return false -- no tool to register
    end

    -- Set default options
    options.privs = options.privs or {teacher = true}
    options.allow_take = options.allow_take or false

    -- Register callbacks
    -- Give the tool to any player who joins with adequate privileges or take it away if they do not have them
    minetest.register_on_joinplayer(function(player)
        local stack = ItemStack(tool)
        local list = get_player_item_location(player, stack)

        if not list and mc_helpers.checkPrivs(player, options.privs) then
            -- Player should have the tool but does not: give one copy
            player:get_inventory():add_item(mc_toolhandler.default_inv, tool)
            if mc_toolhandler.default_inv ~= "main" then
                minetest.chat_send_player(player:get_player_name(), "New tool added to toolbox: "..tool)
            end
        elseif not mc_helpers.checkPrivs(player, options.privs) then
            -- Player has the tool but should not: remove all copies
            local inv = player:get_inventory()
            while list do
                inv:remove_item(list, tool)
                list = get_player_item_location(player, stack)
            end
        else
            -- Make sure player only has one copy of the tool
            if player_has_item_copies(player, ItemStack(tool)) then
                for i,item in pairs(player:get_inventory():get_list(list)) do
                    if item:get_name() == tool then
                        remove_item_copies_except(player, stack, i, list)
                        break
                    end
                end
            end
        end
    end)
    -- Give the tool to any player who is granted adequate privileges
    minetest.register_on_priv_grant(function(name, granter, priv)
        -- Check if priv has an effect on the privileges needed for the tool
        if name == nil or not mc_helpers.tableHas(options.privs, priv) or not minetest.get_player_by_name(name) then
            return true -- skip this callback, continue to next callback
        end
    
        local stack = ItemStack(tool)
        local player = minetest.get_player_by_name(name)
        local list = get_player_item_location(player, stack)

        if mc_helpers.checkPrivs(player, options.privs) then
            if not list then
                -- Player should have the tool but does not: give one copy
                player:get_inventory():add_item(mc_toolhandler.default_inv, tool)
                if mc_toolhandler.default_inv ~= "main" then
                    minetest.chat_send_player(name, "New tool added to toolbox: "..tool)
                end
            elseif player_has_item_copies(player, ItemStack(tool)) then
                -- Player has multiple copies of the tool already: remove all but one
                for i,item in pairs(player:get_inventory():get_list(list)) do
                    if item:get_name() == tool then
                        remove_item_copies_except(player, stack, i, list)
                        break
                    end
                end
            end
        end
        return true -- continue to next callback
    end)
    -- Take the tool away from anyone who is revoked privileges and no longer has adequate ones
    minetest.register_on_priv_revoke(function(name, revoker, priv)
        -- Check if priv has an effect on the privileges needed for the tool
        if name == nil or not mc_helpers.tableHas(options.privs, priv) or not minetest.get_player_by_name(name) then
            return true -- skip this callback, continue to next callback
        end
    
        local stack = ItemStack(tool)
        local player = minetest.get_player_by_name(name)
        local list = get_player_item_location(player, stack)
    
        if list and not mc_helpers.checkPrivs(player, options.privs) then
            -- Player has the tool but should not: remove all copies
            local inv = player:get_inventory()
            while list do
                inv:remove_item(list, tool)
                list = get_player_item_location(player, stack)
            end
        end
        return true -- continue to next callback
    end)

    -- Save options to mod table for future reference
    mc_toolhandler.reg_tools[tool] = options
    return true
end

--- @public
--- Registers a group of similar tools to be managed by `mc_toolhandler` as if they were one tool
--- @param tools Table of itemstrings of tools to be managed
--- @param options Table of tool options
--- @see README.md > API > mc_toolhandler.register_group_manager
function mc_toolhandler.register_group_manager(tools, options)
    if type(tools) ~= "table" or not next(tools) then
        return false
    end

    local function get_first_v(table)
        local k,v = next(table)
        return v
    end

    -- Set default options
    options.privs = options.privs or {teacher = true}
    options.default_tool = options.default_tool or tools[1] or get_first_v(tools)
    options.allow_take = options.allow_take or false

    if not minetest.registered_tools[options.default_tool] or not mc_helpers.tableHas(tools, options.default_tool) then
        return false -- default tool invalid
    end

    -- Get next available group
    local group = mc_toolhandler.next_group
    
    -- Register group callbacks
    -- Give the tool to any player who joins with adequate privileges or take it away if they do not have them
    minetest.register_on_joinplayer(function(player)
        local list, item_name = get_player_group_location(player, group)

        if not list and mc_helpers.checkPrivs(player, options.privs) then
            -- Player should have the tool but does not: give one copy
            player:get_inventory():add_item(mc_toolhandler.default_inv, options.default_tool)
            if mc_toolhandler.default_inv ~= "main" then
                minetest.chat_send_player(player:get_player_name(), "New tool added to toolbox: "..options.default_tool)
            end
        elseif not mc_helpers.checkPrivs(player, options.privs) then
            -- Player has the tool but should not: remove all copies
            local inv = player:get_inventory()
            while list do
                inv:remove_item(list, item_name)
                list, item_name = get_player_group_location(player, group)
            end
        else
            -- Make sure player only has one copy of the tool
            if player_has_group_copies(player, group) then
                for i,item in pairs(player:get_inventory():get_list(list)) do
                    if item:get_name() == item_name then
                        remove_group_copies_except(player, group, i, list)
                    end
                end
            end
        end
    end)
    -- Give the tool to any player who is granted adequate privileges
    minetest.register_on_priv_grant(function(name, granter, priv)
        -- Check if priv has an effect on the privileges needed for the tool
        if name == nil or not mc_helpers.tableHas(options.privs, priv) or not minetest.get_player_by_name(name) then
            return true -- skip this callback, continue to next callback
        end
    
        local player = minetest.get_player_by_name(name)
        local list, item_name = get_player_group_location(player, group)

        if mc_helpers.checkPrivs(player, options.privs) then
            if not list then
                -- Player should have the tool but does not: give one copy
                player:get_inventory():add_item(mc_toolhandler.default_inv, options.default_tool)
                if mc_toolhandler.default_inv ~= "main" then
                    minetest.chat_send_player(name, "New tool added to toolbox: "..options.default_tool)
                end
            elseif player_has_group_copies(player, group) then
                -- Player has multiple copies of the tool already: remove all but one
                for i,item in pairs(player:get_inventory():get_list(list)) do
                    if item:get_name() == item_name then
                        remove_group_copies_except(player, group, i, list)
                    end
                end
            end
        end
        return true -- continue to next callback
    end)
    -- Take the tool away from anyone who is revoked privileges and no longer has adequate ones
    minetest.register_on_priv_revoke(function(name, revoker, priv)
        -- Check if priv has an effect on the privileges needed for the tool
        if name == nil or not mc_helpers.tableHas(options.privs, priv) or not minetest.get_player_by_name(name) then
            return true -- skip this callback, continue to next callback
        end
        
        local player = minetest.get_player_by_name(name)
        local list, item_name = get_player_group_location(player, group)
        
        if list and not mc_helpers.checkPrivs(player, options.privs) then
            -- Player has the tool but should not: remove all copies
            local inv = player:get_inventory()
            while list do
                inv:remove_item(list, item_name)
                list, item_name = get_player_group_location(player, group)
            end
        end
        return true -- continue to next callback
    end)

    for _,tool in pairs(tools) do
        -- Register tool as a group member
        mc_toolhandler.reg_group_tools[tool] = group
    end

    -- Save options to mod table for future reference
    mc_toolhandler.reg_groups[group] = options
    mc_toolhandler.next_group = group + 1
    return true
end

--- Abstract function for checking if a player's inventory contains a tool, and if they have the necessary privileges to use it
--- @param player Player to check
--- @param stack Tool to check for
--- @param abstract Function table defining functions to call for various check results
--- Standard tool branch:
---  - Initial check:
---    - t_np(t_np_p): player does not have privileges
---    - t_pm(t_pm_p): player has privileges and multiple copies of tool
---    - t_else(t_else_p): player has privileges and 0-1 copies of tool
---  - t_final(t_final_p): final call on branch regardless of outcome
--- Tool group branch:
---  - Initial check:
---    - g_np(g_np_p): player does not have privileges
---    - g_pm(g_pm_p): player has privileges and multiple copies of tool
---    - g_else(g_else_p): player has privileges and 0-1 copies of tool
---  - g_final(g_final_p): final call on branch regardless of outcome
--- @return first return from called functions
local function tool_perm_check_abstract(player, stack, abstract)
    local func_return = nil
    if mc_toolhandler.reg_tools[stack:get_name()] then 
        if not mc_helpers.checkPrivs(player, mc_toolhandler.reg_tools[stack:get_name()]["privs"]) then
            func_return = abstract.t_np and abstract.t_np(unpack(abstract.t_np_p or {})) or func_return
        elseif player_has_item_copies(player, stack) then
            func_return = abstract.t_pm and abstract.t_pm(unpack(abstract.t_pm_p or {})) or func_return
        else
            func_return = abstract.t_else and abstract.t_else(unpack(abstract.t_else_p or {})) or func_return
        end
        func_return = abstract.t_final and abstract.t_final(unpack(abstract.t_final_p or {})) or func_return
    else
        local group = mc_toolhandler.reg_group_tools[stack:get_name()]
        if group and mc_toolhandler.reg_groups[group] then
            if not mc_helpers.checkPrivs(player, mc_toolhandler.reg_groups[group]["privs"]) then
                func_return = abstract.g_np and abstract.g_np(unpack(abstract.g_np_p or {})) or func_return
            elseif player_has_group_copies(player, group) then
                func_return = abstract.g_pm and abstract.g_pm(unpack(abstract.g_pm_p or {})) or func_return
            else
                func_return = abstract.g_else and abstract.g_else(unpack(abstract.g_else_p or {})) or func_return
            end
            func_return = abstract.g_final and abstract.g_final(unpack(abstract.g_final_p or {})) or func_return
        end
    end
    return func_return
end

-- Removes duplicate copies of registered items and items the player does not have privileges to use
local function remove_prohibited_items(player, stack, i, list)
    local group = mc_toolhandler.reg_group_tools[stack:get_name()]

    tool_perm_check_abstract(player, stack, {
        t_np = function(player, stack, list)
            -- Player should not have the tool: remove all copies
            local inv = player:get_inventory()
            if not list then
                list = get_player_item_location(player, stack)
            end
            while list do
                inv:remove_item(list, stack:get_name())
                list = get_player_item_location(player, stack)
            end
        end,
        t_np_p = {player, stack, list},

        t_pm = remove_item_copies_except,
        t_pm_p = {player, stack, i, list},

        g_np = function(player, group)
            -- Player does not have privileges to use item: remove all copies
            local inv = player:get_inventory()
            local list, item_name = get_player_group_location(player, group)
            while list do
                inv:remove_item(list, item_name)
                list, item_name = get_player_group_location(player, group)
            end
        end,
        g_np_p = {player, group},

        g_pm = remove_group_copies_except,
        g_pm_p = {player, group, i, list}
    })
end

-- Register callbacks for preventing specified tools from being taken
minetest.register_allow_player_inventory_action(function(player, action, inventory, inv_info)
    if action == "take" then
        local tool = inv_info.stack:get_name()
        if mc_toolhandler.reg_tools[tool] then
            if not mc_toolhandler.reg_tools[tool]["allow_take"] then
                return 0 -- do not allow item to be taken
            end
        elseif mc_toolhandler.reg_group_tools[tool] and mc_toolhandler.reg_groups[mc_toolhandler.reg_group_tools[tool]] then
            if not mc_toolhandler.reg_groups[mc_toolhandler.reg_group_tools[tool]]["allow_take"] then
                return 0 -- do not allow item to be taken
            end
        end
    end
    return -- ignore
end)

-- Register callbacks for removing duplicate tools and items player should not have
minetest.register_on_player_inventory_action(function(player, action, inventory, inv_info)
    if action == "put" or action == "take" then
        remove_prohibited_items(player, inv_info.stack, inv_info.index, inv_info.listname)
    elseif action == "move" then
        local stack_1 = inventory:get_stack(inv_info.to_list, inv_info.to_index)
        remove_prohibited_items(player, stack_1, inv_info.to_index, inv_info.to_list)
        local stack_2 = inventory:get_stack(inv_info.from_list, inv_info.from_index)
        remove_prohibited_items(player, stack_2, inv_info.from_index, inv_info.from_list)
    end
end)

minetest.register_on_chatcommand(function(name, command, params)
    if command == "give" or command == "giveme" then
        local p_table = mc_helpers.split(params, " ")
        if not p_table[1] or (command == "give" and not p_table[2]) then return end -- missing params, skip

        local player = (command == "giveme" and minetest.get_player_by_name(name)) or minetest.get_player_by_name(p_table[1])
        if not player then return end -- player not found, skip

        local stack_name = (command == "giveme" and p_table[1]) or p_table[2]
        local stack = ItemStack(stack_name)

        local group = mc_toolhandler.reg_group_tools[stack:get_name()]

        local function fail_and_send_privs(name, privs)
            local keys = {}
            for k,v in pairs(privs) do
                table.insert(keys, k)
            end
            minetest.chat_send_player(name, "Target player is missing privileges required for item use: "..table.concat(keys, ", ")..".")
            return true
        end

        return tool_perm_check_abstract(player, stack, {
            t_np = function(name, stack)
                local stack_privs = mc_toolhandler.reg_tools[stack:get_name()] and mc_toolhandler.reg_tools[stack:get_name()]["privs"] or {teacher = true}
                return fail_and_send_privs(name, stack_privs)
            end,
            t_np_p = {name, stack},

            t_pm = remove_prohibited_items,
            t_pm_p = {player, stack},

            t_final = function(player, stack, name)
                if get_player_item_location(player, stack) then
                    minetest.chat_send_player(name, "Target player already has the specified item.")
                    return true
                end
            end,
            t_final_p = {player, stack, name},

            g_np = function(name, group)
                local group_privs = mc_toolhandler.reg_groups[group] and mc_toolhandler.reg_groups[group]["privs"] or {teacher = true}
                return fail_and_send_privs(name, group_privs)
            end,
            g_np_p = {name, group},

            g_pm = remove_prohibited_items,
            g_pm_p = {player, stack},

            g_final = function(player, group, name)
                if group and get_player_group_location(player, group) then
                    minetest.chat_send_player(name, "Target player already has the specified item.")
                    return true
                end
            end,
            g_final_p = {player, group, name}
        })
    end
end)

--- @public
--- Returns a detached inventory containing all tools `player` has the privileges to use, which `player` can freely take copies of as desired
--- It is recommended to call this every time access to the detached inventory is needed in case player privileges change between uses
--- @param player Player to generate the detached inventory for
--- @return InvRef, string, string
function mc_toolhandler.create_tool_inventory(player)
    local pname = player:get_player_name()
    local inv_name = "mc_toolhandler:"..pname
    local list_name = "store"

    -- get detached inventory, or initialize if it doesn't already exist
    local store_inv = minetest.get_inventory({type = "detached", name = inv_name})
    if not store_inv then
        store_inv = minetest.create_detached_inventory(inv_name, {
            allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
                -- static inventory: do not allow items to be moved
                return 0
            end,
            allow_put = function(inv, listname, index, stack, player)
                -- static inventory: do not allow items to be put in
                return 0
            end,
            allow_take = function(inv, listname, index, stack, player)
                if not mc_helpers.checkPrivs(player, mc_toolhandler.reg_tools[stack:get_name()]) then
                    -- no permissions: do not allow player to take item
                    return 0
                else
                    -- permissions: allow player to take copy of item, keep original copy
                    return -1
                end
            end,
        }, pname)
    end

    -- clear existing store list
    store_inv:set_list(list_name, {})
    local tools_to_check = mc_helpers.shallowCopy(mc_toolhandler.reg_tools)
    for id,options in pairs(mc_toolhandler.reg_groups) do
        tools_to_check[options.default_tool] = {privs = options.privs, allow_take = options.allow_take}
    end
    local count = 0

    -- add items to store
    for item,options in pairs(tools_to_check) do
        local stack = ItemStack(item)
        if stack and mc_helpers.checkPrivs(player, options["privs"]) then
            count = count + 1
            store_inv:set_size(list_name, count)
            store_inv:add_item(list_name, stack)
        end
    end

    return store_inv, inv_name, list_name
end

-- TOOL STORE TEST NODE
minetest.register_node("mc_toolhandler:test_store", {
    description = "Tool store test node",
    tiles = {"mc_toolhandler_test_store.png"},
    groups = {dig_immediate = 2},
    on_rightclick = function(pos, node, player, itemstack, pointed_thing)
        local pname = player:get_player_name()
        local store, inv_name, list_name = mc_toolhandler.create_tool_inventory(player)
        local formtable = {
            "formspec_version[5]",
            "size[10.5,11]",
            "list[detached:", inv_name, ";", list_name, ";0.4,0.9;8,2;0]",
            "list[current_player;main;0.4,5.9;8,4;0]",
            "listring[]",
            "label[0.4,0.5;", minetest.formspec_escape("[TEST]"), " Shopping time!]",
        }
        minetest.show_formspec(pname, "mc_toolhandler:store", table.concat(formtable, ""))
    end
})