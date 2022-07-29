mc_toolmenu = {
    path = minetest.get_modpath("mc_toolmenu"),
    tool_inv = "mc_toolmenu:tools"
}

sfinv.register_page(mc_toolmenu.tool_inv, {
    title = "Toolbox",
    get = function(self, player, context)
        local pname = player:get_player_name()
        local box_height = math.ceil(player:get_inventory():get_size(mc_toolmenu.tool_inv)/8) - 4
        local scroll_const = 23/20 -- 23/20 = 1.15
        local formtable = {
            "box[-0.28,-0.30;8.35,4.5;#555555]",
        }
        if box_height > 0 then
            table.insert_all(formtable, {
                "scrollbaroptions[min=0;max=", scroll_const * box_height, ";smallstep=", scroll_const, ";largestep=", scroll_const * 4, ";thumbsize=", scroll_const, "]",
                "scrollbar[7.85,0;0.2,3.9;vertical;toolbox_scroll;0]",
            })
        else
            box_height = 0
        end
        table.insert_all(formtable, {
            "scroll_container[0,0;10.15,4.88;toolbox_scroll;vertical;", scroll_const, "]",
            "list[current_player;mc_toolmenu:tools;0,0;8,", box_height + 4, ";0]",
            "listring[]",
            "scroll_container_end[]"
        })
        return sfinv.make_formspec(player, context, table.concat(formtable, ""), true)
    end
})

minetest.register_on_joinplayer(function(player)
    -- player check
    if not player:is_player() then return end

    local pname = player:get_player_name()
    local inv = player:get_inventory()

    -- register toolbox if not already created
    if not inv:get_list(mc_toolmenu.tool_inv) then
        inv:set_list(mc_toolmenu.tool_inv, {})
        inv:set_size(mc_toolmenu.tool_inv, 32)
    end
end)

minetest.register_allow_player_inventory_action(function(player, action, inventory, inv_info)
    -- initial check
    local list_info = inv_info.listname or (inv_info.to_list == mc_toolmenu.tool_inv and inv_info.to_list or inv_info.from_list)
    if list_info ~= mc_toolmenu.tool_inv then
        return -- toolbox not affected, ignore
    end

    if action == "move" then
        if inv_info.to_list == mc_toolmenu.tool_inv then
            -- putting item into toolbox, run checks
            local moving_stack = inventory:get_stack(inv_info.from_list, inv_info.from_index)
            if minetest.registered_tools[moving_stack:get_name()] then 
                return 1 -- allow 1 item (tool) to be put in
            else
                return 0 -- do not allow item to be put in
            end
        else
            return -- no items going into toolbox, ignore
        end
    elseif action == "put" and inv_info.listname == mc_toolmenu.tool_inv then
        if minetest.registered_tools[inv_info.stack:get_name()] then 
            return 1 -- allow 1 item (tool) to be put in
        else
            return 0 -- do not allow item to be put in
        end
    else
        return -- ignore
    end
end)

minetest.register_on_player_inventory_action(function(player, action, inventory, inv_info)
    -- initial check
    local list_info = inv_info.listname or (inv_info.to_list == mc_toolmenu.tool_inv and inv_info.to_list or inv_info.from_list)
    if list_info ~= mc_toolmenu.tool_inv then
        return -- toolbox not affected, ignore
    end

    if not inventory:room_for_item(mc_toolmenu.tool_inv, ItemStack("default:pick_bronze")) then
        -- Increase size of toolbox if it gets full
        local current_size = inventory:get_size(mc_toolmenu.tool_inv)
        inventory:set_size(mc_toolmenu.tool_inv, current_size + 8)

        -- refresh inventory formspec
        sfinv.set_player_inventory_formspec(player)
    end
end)
