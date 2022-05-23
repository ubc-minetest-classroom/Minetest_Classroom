minetest_classroom.classrooms = minetest.get_mod_storage()

-- Required MT version
assert(minetest.features.formspec_version_element, "Minetest 5.1 or later is required")

-- Internationalisaton
minetest_classroom.S = minetest.get_translator("minetest_classroom")
minetest_classroom.FS = function(...)
	return minetest.formspec_escape(minetest_classroom.S(...))
end

-- Source files
dofile(minetest.get_modpath("mc_teacher") .. "/api.lua")
dofile(minetest.get_modpath("mc_teacher") .. "/gui_dash.lua")
dofile(minetest.get_modpath("mc_teacher") .. "/gui_group.lua")
dofile(minetest.get_modpath("mc_teacher") .. "/freeze.lua")
dofile(minetest.get_modpath("mc_teacher") .. "/actions.lua")

-- Privileges
minetest.register_privilege("teacher", {
	give_to_singleplayer = false
})

-- Hooks needed to make api.lua testable
minetest_classroom.get_connected_players = minetest.get_connected_players
minetest_classroom.get_player_by_name = minetest.get_player_by_name
minetest_classroom.check_player_privs = minetest.check_player_privs

minetest_classroom.load_from(minetest_classroom.classrooms)

function minetest_classroom.save()
	minetest_classroom.save_to(minetest_classroom.classrooms)
end

minetest.register_on_shutdown(minetest_classroom.save)
