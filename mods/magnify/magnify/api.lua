-- EXPORTED MAGNIFY FUNCTIONS
magnify = {}

--- @public
--- Registers a plant species in the `magnify` plant database
--- @param def_table Plant species definition table
--- @param nodes Table of stringified nodes the species corresponds to in the MineTest world
--- @see README.md > API > Registration
function magnify.register_plant(def_table, nodes)
    local ref = magnify_plants:get("count") or 1
    local serial_table = minetest.serialize(def_table)
    magnify_plants:set_string("ref_"..ref, serial_table)

    for k,v in pairs(nodes) do
        magnify_plants:set_string("node_"..v, "ref_"..ref)
    end

    magnify_plants:set_int("count", ref + 1)
end

--- @public
--- Returns the reference key associated with `node` in the `magnify` plant database
--- @param node Stringified node
--- @return string or nil
function magnify.get_ref(node)
    return magnify_plants:get("node_"..node)
end

--- @public
--- Clears a plant species and all its associated nodes from the `magnify` plant database
--- @param ref Reference key of the plant species to clear
function magnify.clear_ref(ref)
    local storage_data = magnify_plants:to_table()
    for k,v in pairs(storage_data.fields) do
        if k == ref or v == ref then
            magnify_plants:set_string(k, "")
        end
    end
end

--- @private
--- Clears a node from the magnify database and returns the reference key the removed node key pointed to
--- @param node Stringified node to clear
--- @return string or nil
local function clear_node_key(node)
    old_ref = magnify.get_ref(node)
    magnify_plants:set_string("node_"..node, "")
    return old_ref
end

--- @public
--- Clears the nodes in `nodes` from the `magnify` plant database
--- Then, clears any plants species that are no longer associated with any nodes as a result of clearing the nodes in `nodes`
--- @param nodes Table of stringified nodes to clear
function magnify.clear_nodes(nodes)
    -- remove node keys
    local changed_refs = {}
    for _,node in pairs(nodes) do
        table.insert(changed_refs, clear_node_key(node))
    end

    -- check affected refs to ensure that node still point to them
    local storage_data = magnify_plants:to_table()
    for k,v in pairs(storage_data.fields) do
        for i,ref in pairs(changed_refs) do
            if v == ref then
                changed_refs[i] = nil
            end
        end
    end

    -- remove affected refs which no longer have nodes pointing to them
    for _,ref in pairs(changed_refs) do
        magnify.clear_ref(ref)
    end
end

--- @public
--- Returns the plant definition table the species indexed at `ref` in the `magnify` plant database, and a list of nodes the species is associated with
--- @param ref Reference key of the plant species
--- @return table, table or nil
function magnify.get_species_from_ref(ref)
    local storage_data = magnify_plants:to_table()
    local output_nodes = {}
  
    if magnify_plants:get(ref) then
        local data = minetest.deserialize(magnify_plants:get_string(ref))
        if data then
            for k,v in pairs(storage_data.fields) do
                if v == ref then
                    table.insert(output_nodes, string.sub(k, 6))
                end
            end
            return data,output_nodes
        else
            return nil
        end
    else
        return nil
    end
end

--- @private
--- Sorting comparison function for registered plant species
--- Sorts by common name, then scientific name, in alphabetical order
--- Fallbacks:
--- If both ref_a and ref_b are invalid, returns ref_a < ref_b (default sort)
--- If exactly one of ref_a and ref_b is invalid, returns whether ref_a is valid or not
--- @param ref_a Reference key of the first species to be sorted
--- @param ref_b Reference key of the second species to be sorted
--- @return boolean
local function species_compare(ref_a, ref_b)
    local species_a = magnify.get_species_from_ref(ref_a)
    local species_b = magnify.get_species_from_ref(ref_b)
    if species_a and species_b then
        if species_a.com_name ~= species_b.com_name then
            return species_a.com_name < species_b.com_name
        else
            return species_a.sci_name < species_b.sci_name
        end
    elseif not species_a and not species_b then
        return ref_a < ref_b
    else
        return species_a or false
    end
end

--- @public
--- Returns a human-readable list of all species registered in the `magnify` plant database, and a list of reference keys corresponding to them
--- Each species and its corresponding reference key will be at the same index in both lists
--- @return table, table
function magnify.get_all_registered_species()
    local storage_data = magnify_plants:to_table()
    local raw_name_table = {}
    local ref_keys = {}

    for k,v in pairs(storage_data.fields) do
        if string.sub(k, 1, 4) == "ref_" then
            local info = minetest.deserialize(v)
            if info then
                --local ref_num = string.sub(k, 5)
                raw_name_table[k]  = info.com_name .. " (" .. info.sci_name .. ")"
                table.insert(ref_keys, k)
            end
        end
    end

    local name_table = {}
    table.sort(ref_keys, species_compare)
    for i,k in ipairs(ref_keys) do
        name_table[i] = raw_name_table[k]
    end

    return name_table, ref_keys
end

--- @public
--- Builds the general plant information formspec for the species indexed at `ref` in the `magnify` plant database 
--- @param ref Reference key of the plant species
--- @param is_exit true if clicking the "Back" button should exit the formspec, false otherwise
--- @param is_inv true if the formspec is being used in the player inventory, false otherwise
--- @return formspec string, formspec "size[]" string or nil
function magnify.build_formspec_from_ref(ref, is_exit, is_inv)
    local info = minetest.deserialize(magnify_plants:get(ref))
    
    -- TODO: create V1 and V2 formtables
    if info ~= nil then
        -- entry good, return formspec
        if info.model_obj and info.model_spec and info.texture then
            -- v2: model and image
            local size = (is_inv and "size[13.8,7.2]") or "size[17.4,9.3]"
            local formtable_v2 = {
                "formspec_version[5]", size,

                "box[", (is_inv and "0,0;10,1.6") or "0.4,0.4;12,1.6", ";", minetest.formspec_escape(info.status_col or "#9192A3"), "]",
                "textarea[", (is_inv and "0.45,0.08;10.4,0.7") or "0.45,0.45;12.4,0.7", ";;;", minetest.formspec_escape(info.sci_name or "N/A"), "]",
                "textarea[", (is_inv and "0.45,0.59;10.4,0.7") or "0.45,0.96;12.4,0.7", ";;;", minetest.formspec_escape((info.com_name and "Common name: "..info.com_name) or "Common name unknown"), "]",
                "textarea[", (is_inv and "0.45,1.1;10.4,0.7") or "0.45,1.47;12.4,0.7", ";;;", minetest.formspec_escape((info.fam_name and "Family: "..info.fam_name) or "Family unknown"), "]",

                "image[", (is_inv and "10.3,0") or "12.8,0.4", ";4.2,4.2;", info.texture or "test.png", "]",
                "box[", (is_inv and "10.3,3.7;3.35,3.65") or "12.8,4.7;4.2,4.2", ";#789cbf]",
                "model[", (is_inv and "10.3,3.7") or "12.8,4.7", ";4.2,4.2;plant_model;", info.model_obj, ";", info.model_spec, ";0,180;false;true;;]",

                "textarea[", (is_inv and "0.3,1.8;10.45,4.7") or "0.35,2.3;12.4,4.7", ";;;", -- info area
                "- ", minetest.formspec_escape(info.cons_status or "Conservation status unknown"), "\n",
                "- ", minetest.formspec_escape((info.region and "Found in "..info.region) or "Location range unknown"), "\n",
                "- ", minetest.formspec_escape(info.height or "Height unknown"), "\n",
                "\n",
                minetest.formspec_escape((info.more_info and info.more_info.."\n") or ""),
                minetest.formspec_escape(info.bloom or "Bloom pattern unknown"),
                "]",

                "textarea[", (is_inv and "0.3,6;10.4,0.7") or "0.35,7.2;12.4,0.7", ";;;", minetest.formspec_escape((info.img_copyright and "Image © "..info.img_copyright) or (info.img_credit and "Image courtesy of "..info.img_credit) or ""), "]",
                --"label[0.4,7.15;", minetest.formspec_escape((info.external_link and "You can find more information at:") or ""), "]",
                --"textarea[0.35,7.35;12.2,0.6;;;", minetest.formspec_escape(info.external_link or ""), "]",
                "button", (is_exit and "_exit") or "", "[", (is_inv and "0,6.75;10.2,0.6") or "0.4,8;12,0.9", ";back;Back]"
            }
            return table.concat(formtable_v2, ""), size
        else
            -- v1: image
            local size = (is_inv and "size[14.7,5.9]") or "size[18.5,7.7]"
            local formtable_v1 = {  
                "formspec_version[5]", size,
                
                "box[", (is_inv and "0,0;9.6,1.6") or "0.4,0.4;11.6,1.6", ";", minetest.formspec_escape(info.status_col or "#9192a3"), "]",
                "textarea[", (is_inv and "0.45,0.08;10,0.7") or "0.45,0.45;12.4,0.7", ";;;", minetest.formspec_escape(info.sci_name or "N/A"), "]",
                "textarea[", (is_inv and "0.45,0.59;10,0.7") or "0.45,0.96;12.4,0.7", ";;;", minetest.formspec_escape((info.com_name and "Common name: "..info.com_name) or "Common name unknown"), "]",
                "textarea[", (is_inv and "0.45,1.1;10,0.7") or "0.45,1.47;12.4,0.7", ";;;", minetest.formspec_escape((info.fam_name and "Family: "..info.fam_name) or "Family unknown"), "]",
                "image[", (is_inv and "9.9,0") or "12.4,0.4", ";5.7,5.7;", info.texture or "test.png", "]",
                --"model[12.4,0.4;5.4,5.4;test_tree;tree_test.obj;default_acacia_tree_top.png,default_dry_grass_2.png,default_dry_dirt.png^default_dry_grass_side.png,default_acacia_leaves.png,default_acacia_tree.png,default_dry_grass_1.png,default_dry_grass_3.png,default_dry_grass_4.png,default_dry_grass.png;0,180;false;true;;]",
    
                "textarea[", (is_inv and "0.3,1.8;10.05,4.3") or "0.35,2.3;12,4.4", ";;;", -- info area
                "- ", minetest.formspec_escape(info.cons_status or "Conservation status unknown"), "\n",
                "- ", minetest.formspec_escape((info.region and "Found in "..info.region) or "Location range unknown"), "\n",
                "- ", minetest.formspec_escape(info.height or "Height unknown"), "\n",
                "\n",
                minetest.formspec_escape((info.more_info and info.more_info.."\n") or ""),
                minetest.formspec_escape(info.bloom or "Bloom pattern unknown"),
                "]",

                "textarea[", (is_inv and "0.3,5.6;11.6,0.7") or "0.35,6.9;11.6,0.7", ";;;", minetest.formspec_escape((info.img_copyright and "Image © "..info.img_copyright) or (info.img_credit and "Image courtesy of "..info.img_credit) or ""), "]",
                --"label[0.4,6.75;", minetest.formspec_escape((info.external_link and "You can find more information at:") or ""), "]",
                --"textarea[0.35,6.9;11.6,0.6;;;", minetest.formspec_escape(info.external_link or ""), "]",
		
                "button", (is_exit and "_exit") or "", "[", (is_inv and "9.9,5.4;4.8,0.6") or "12.4,6.4;5.7,0.9", ";back;Back]"
            }
            return table.concat(formtable_v1, ""), size
        end
    else
        -- entry bad, go to fallback
        return nil
    end
end

--[[ formtable clean copies, for editing
-- V2
formspec_version[5]
size[17.4,9.3]
box[0.4,0.4;12,1.6;", minetest.formspec_escape(info.status_col or "#9192A3"), "]
textarea[0.45,0.45;12.4,0.7;;;", minetest.formspec_escape(info.sci_name or "N/A"), "]
textarea[0.45,0.97;12.4,0.7;;;", minetest.formspec_escape((info.com_name and "Common name: "..info.com_name) or "Common name unknown"), "]
textarea[0.45,1.47;12.4,0.7;;;", minetest.formspec_escape((info.fam_name and "Family: "..info.fam_name) or "Family unknown"), "]
image[12.8,0.4;4.2,4.2;", info.texture or "test.png", "]
box[12.8,4.7;4.2,4.2;#789cbf]
textarea[0.35,2.3;12.4,4.7;;;"add the original giant text box here"]
textarea[0.35,7.2;12.4,0.7;;;", minetest.formspec_escape((info.img_copyright and "Image © "..info.img_copyright) or (info.img_credit and "Image courtesy of "..info.img_credit) or ""), "]
button[0.4,8;12,0.9;back;Back]

-- V1
formspec_version[5]
size[18.5,7.7]
box[0.4,0.4;11.6,1.6;", minetest.formspec_escape(info.status_col or "#9192a3"), "]
textarea[0.45,0.45;12,0.7;;;", minetest.formspec_escape(info.sci_name or "N/A"), "]
textarea[0.45,0.97;12,0.7;;;", minetest.formspec_escape((info.com_name and "Common name: "..info.com_name) or "Common name unknown"), "]
textarea[0.45,1.47;12,0.7;;;", minetest.formspec_escape((info.fam_name and "Family: "..info.fam_name) or "Family unknown"), "]
image[12.4,0.4;5.7,5.7;", minetest.formspec_escape(info.texture or "test.png"), "]
textarea[0.35,2.3;12,4.4;;;"add the original giant text box here"]
textarea[0.35,6.9;11.6,0.7;;;", minetest.formspec_escape((info.img_copyright and "Image © "..info.img_copyright) or (info.img_credit and "Image courtesy of "..info.img_credit) or ""), "]
button[12.4,6.4;5.4,0.9;back;Back]
]]

--- @public
--- Returns true if any of the keys or values in `table` match `val`, false otherwise
--- @param table The table to check
--- @param val The key/value to check for
--- @return boolean
function magnify.table_has(table, val)
    if not table or not val then return false end
    for k,v in pairs(table) do
        if k == val or v == val then return true end
    end
    return false
end