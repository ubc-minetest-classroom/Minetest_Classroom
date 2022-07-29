local S = forestry_tools.S

-- Allows zooming
 minetest.register_tool("forestry_tools:wedgeprism", {
    description = S("Wedge Prism"),
    wield_image = "wedgeprism.jpg",
    inventory_image = "wedgeprism.jpg",
	on_drop = function(itemstack, dropper, pos)
	end,
})

if minetest.get_modpath("mc_toolhandler") then
	mc_toolhandler.register_tool_manager("forestry_tools:wedgeprism", {privs = forestry_tools.priv_table})
end


minetest.register_privilege("alwayszoom", {})


--       function update_wedge(player)
--                  local wielding = player:get_wielded_item()
--              local playername = player:get_player_name()
--                 local privs = minetest.get_player_privs(playername)
--                 if not wielding:is_empty() and wielding:get_name() == "forestry_tools:wedgeprism" then
--                         -- Has prism
--                         if privs.zoom ~= true then
--                                  privs.zoom = true
--                                  minetest.set_player_privs(playername, privs)
--                          end
--                 else
--                         -- Does not have prism
--                         if privs.zoom == true then
--                                 privs.zoom = nil
--                                 minetest.set_player_privs(playername, privs)
--                      end
--                  end
--          end



minetest.register_globalstep(function()
	for _,player in ipairs(minetest.get_connected_players()) do
		local name = player:get_player_name()
		local privs = minetest.get_player_privs(name)
		if not privs.zoom and player:get_wielded_item():get_name()=="forestry_tools:wedgeprism" then
			privs.zoom = true
			minetest.set_player_privs(name, privs)
		elseif privs.zoom and player:get_wielded_item():get_name()~="forestry_tools:wedgeprism" and not privs.alwayszoom then
			privs.zoom = nil
			minetest.set_player_privs(name, privs)
		end
	end
end)




       --  function init_hud(player)   

      --      update_wedge(player)
