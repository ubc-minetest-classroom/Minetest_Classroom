local magnify = dofile(minetest.get_modpath("magnify").."/api.lua")

--[[
local template = {
    sci_name = "",        -- Scientific name of species
    com_name = "",        -- Common name of species
    fam_name = "",        -- Family name of species
    cons_status = "",     -- Conservation status of species
    status_col = "",      -- Hex colour of status box ("#000000")
    height = "",          -- Plant height (information row 3)
    bloom = "",           -- The way the plant blooms
    region = "",          -- Native region of plant (displayed as "Native to [region]")
    texture = "",         -- Image of plant (in `mod/textures`)
    more_info = "",       -- Description of plant
    external_link = "",   -- Link to page with more plant information
    img_copyright = "",   -- Copyright owner of plant image (displayed as "Image (c) [img_copyright]")
    img_credit = ""       -- Author of plant image (displayed as "Image courtesy of [img_credit]")
}
-- Plant registration call
magnify.register_plant(template, {"mod:node", "mod:another_node", "other_mod:other_node"})
]]

-- TASK: finish tables
local aspen = {
    sci_name = "Populus tremuloides",
    com_name = "Trembling Aspen",
    fam_name = "Salicaceae (Willow family)",
    cons_status = "S5 - Demonstrably widespread, abundant, and secure",
    status_col = "#666ae3", -- S5
    height = "25 meters tall",
    bloom = "Has smooth, round to triangular-shaped leaves with a flattened stalk",
    region = "most of North America",
    texture = "aspen_tree.jpg", 
    more_info = "Smooth-barked, randomly-branching tree. Also known as the golden aspen, due to the golden colour its leaves turn in the fall.",
    external_link = "https://linnet.geog.ubc.ca/Atlas/Atlas.aspx?sciname=Populus%20tremuloides"--,
    --img_copyright or img_credit = ""
  
  -- add copy or credit
}
magnify.register_plant(aspen, {"default:aspen_tree", "default:aspen_wood", "default:aspen_leaves", "default:aspen_sapling"})

local pine = {
    sci_name = "Pinus contorta",
    com_name = "Lodgepole Pine",
    fam_name = "Pinaceae (Pine family)",
    cons_status = "S5 - Demonstrably widespread, abundant, and secure",
    status_col = "#666ae3", -- S5
    height = "21 to 24 meters tall",
    bloom = "Produces yellowish pollen from May to July, depending on the elevation",
    region = "the Northern Hemisphere",
    texture = "pine_tree.jpg",
    more_info = "Large, straight trunked, column-like tree with a narrow, open crown",
    external_link = "https://linnet.geog.ubc.ca/Atlas/Atlas.aspx?sciname=Pinus%20contorta"--, 
    --img_copyright or img_credit = ""
}
magnify.register_plant(pine, {"default:pine_tree", "default:pine_wood", "default:pine_needles", "default:pine_sapling"})

local AppleTree = {
    sci_name = "Malus fusca",
    com_name = "Pacific crab apple (Oregon crabapple)",
    fam_name = "Rosaceae (Rose family)",
    cons_status = "S5 - Demonstrably widespread, abundant, and secure",
    status_col = "#666ae3", -- S5
    height = "2 to 12 meters tall",
    bloom = "Has bright, fragrant clusters of 5-12 white/pink flowers on its branch ends",
    region = "the BC Interior, Southern Ontario & Quebec",
    texture = "apple_tree.jpg",
    more_info = "Bears very crisp, medium-sized, semi-sweet fruit with a thin, red-striped skin that is very aromatic",
    external_link = "https://linnet.geog.ubc.ca/Atlas/Atlas.aspx?sciname=Malus%20fusca"--,
    --img_copyright or img_credit = ""
}
magnify.register_plant(AppleTree, {"default:tree", "default:apple", "default:apple_mark", "default:leaves", "default:sapling"})

local JungleTree = {
    sci_name = "Alnus rubra",
    com_name = "Red alder",
    fam_name = "Betulaceae (Birch family)", 
    cons_status = "S5 - Demonstrably widespread, abundant, and secure",
    status_col = "#666ae3", -- S5
    height = "Grows up to 24 meters tall",
    bloom = "Produces long, droopy, reddish male catkins or short, woody female cones",
    --region = "",
    texture = "jungle_tree.jpg",
    more_info = "Trees growing in the forest develop a slightly tapered trunk extending up to a narrow, rounded crown.",
    external_link = "https://www.for.gov.bc.ca/hfd/library/documents/treebook/redalder.htm"--,
    --img_copyright or img_credit = ""
}
magnify.register_plant(JungleTree, {"default:jungletree","default:junglewood","default:jungleleaves","default:junglesapling","default:emergent_jungle_sapling"})

local Kelp = {
    sci_name = "Desmarestia ligulata",
    com_name = "Flattened acid kelp" ,
    fam_name = "Desmarestiaceae (Brown algae family)",
    cons_status = "Unlisted", -- new colour (use default gray?)
    status_col = "#808080", -- default gray 
    height = "40 to 80 centimeters tall",
    bloom = "Blooms are caused by excess silicate in a body of water", -- where a type of algae called “diatoms” thrive
    region = "the waters of the Northern Hemisphere", -- bodies of water across the globe
    texture = "kelp.jpg",
    more_info = "",
    external_link = "https://linnet.geog.ubc.ca/Atlas/Atlas.aspx?sciname=Desmarestia%20ligulata"--,
    --img_copyright or img_credit = ""
}
magnify.register_plant(Kelp, {"default:sand_with_kelp"})

local blueberry = {
    sci_name = "Vaccinium ovatum",
    com_name = "Evergreen Huckleberry",
    fam_name = "Ericaceae (Crowberry family)",
    cons_status = "S5 - Demonstrably widespread, abundant, and secure",
    status_col = "#666ae3", -- S5
    bloom = "pinkish red that blooms from April to May",
    region = "BC",
    texture = "blueberry.png", 
    more_info = "Can tolerate a wide range of light conditions and is very attractive to birds. Foliage is glossy and green with new red growth",
    external_link = "https://linnet.geog.ubc.ca/Atlas/Atlas.aspx?sciname=Vaccinium%20ovatum"--,
    --img_copyright or img_credit = ""
}
magnify.register_plant(blueberry, {"default:blueberry_bush_leaves", "default:blueberry_bush_leaves_with_berries", "default:blueberries"})

local Bush = {
    sci_name = "Physocarpus capitatus",
    com_name = "Pacific ninebark",
    fam_name = "Rosaceae (Rose family)",
    cons_status = "S5 - Demonstrably widespread, abundant, and secure",
    status_col = "#666ae3", -- S5
    --height = "",
    --bloom = "",
    region = "Southern BC and California",
    texture = "bush.jpeg",
    more_info = "Has showy white flower clusters. Attracts native bees and butterflies, and gives great cover for birds and small mammals.",
    external_link = "https://linnet.geog.ubc.ca/Atlas/Atlas.aspx?sciname=Physocarpus%20capitatus"--,
    --img_copyright or img_credit = ""
}
magnify.register_plant(Bush, {"default:bush_leaves", "default:bush_stem", "default:bush_sapling"})

local Acacia = {
    sci_name = "Quercus garryana",
    com_name = "Garry Oak",
    fam_name = "Fagaceae (Beech family)",
    cons_status = "S5 - Demonstrably widespread, abundant, and secure",
    status_col = "#666ae3", -- S5
    height = "Grows up to 25 metres tall",
    bloom = "Female flowers clustered on same tree, male flowers numerous in catkins",
    region = "Southeastern Vancouver Island and Gulf Islands",
    texture = "acacia.png", 
    more_info = "Deciduous tree with heavy, craggy branches, up to 25 m tall but often small, shrubby and as short as 1 m in dry, rocky habitats",
    external_link = "https://linnet.geog.ubc.ca/Atlas/Atlas.aspx?sciname=Quercus%20garryana"
    --img_copyright or img_credit = ""
    --"https://www.google.com/url?q=https://linnet.geog.ubc.ca/Atlas/Atlas.aspx?sciname%3DQuercus%2520garryana&sa=D&source=editors&ust=1653081882250994&usg=AOvVaw0ijQhcVb59jmz2JSD8np-I"
}
magnify.register_plant(Acacia, {"default:acacia_tree", "default:acacia_wood", "default:acacia_leaves", "default:acacia_sapling", "default:dry_shrub"})

local Cactus = {
    sci_name = "Opuntia fragilis",
    com_name = "Brittle Prickly-pear Cactus",
    fam_name = "Cactaceae (Cactus family)",
    cons_status = "S5 - Demonstrably widespread, abundant, and secure",
    status_col = "#666ae3", -- S5
    height = "5 to 20 cm tall",
    bloom = "Blooms with paper-thin petals, yelllow, 3-5 cm across with reddish stalks",
    region = "British Columbia",
    texture = "catcus.jpeg", 
    more_info = "Perennial herb from a fibrous root; mat-forming; stems prostrate, succulent, subglobose to rounded, fleshy,",
    external_link = "https://linnet.geog.ubc.ca/Atlas/Atlas.aspx?sciname=Opuntia%20fragilis&noTransfer=0",
    img_credit = "the UBC Botanical Garden"
}
magnify.register_plant(Cactus, {"default:cactus", "default:large_cactus_seedling"})

local Papyrus = {
    sci_name = "Equisetum telmateia Ehrh.",
	com_name = "Giant Horsetail",
  	fam_name = "Equisetaceae",
  	cons_status = "S5 - Demonstrably widespread, abundant, and secure",
  	status_col = "#666ae3", 
  	height = "15-150 cm tall",
  	bloom = "non-flowering",
	region = "requent in coastal BC, rare east of the Coast-Cascade Mountains",
	texture = "horsetail.jpeg", 
	more_info = "An evergreen perennial. It has vertical green stems with horizontal bands similar to bamboo",
	external_link = "https://linnet.geog.ubc.ca/Atlas/Atlas.aspx?sciname=Equisetum%20telmateia"--,
  	--img_copyright or img_credit = ""
}
magnify.register_plant(Papyrus, {"default:papyrus"})

--[[
local wild_cotton = { -- part of farming mod so hold on for now 
    sci_name = "",       
    com_name = "",        
    fam_name = "",        
    cons_status = "",     
    status_col = "",     
    height = "",         
    bloom = "",           
    region = "",         
    texture = "",        
    more_info = "",      
    external_link = "",   
    img_credit = ""
}
magnify.register.. ]]

local Fern = {
    sci_name = "Struthiopteris spicant",       
    com_name = "Deer Fern",        
    fam_name = "Blechnaceae (Chain Fern family)",        
    cons_status = "S5 - Demonstrably widespread, abundant, and secure",     
    status_col = "#666ae3",     
    height = "grow to 20 inches tall at maturity",         
    bloom = "not applicable",           
    region = "common in coastal BC, infrequent in SE BC",         
    texture = "fern.png",        
    more_info = "This fern is particularly distinctive because of its two different types of fronds",      
    external_link = "https://linnet.geog.ubc.ca/Atlas/Atlas.aspx?sciname=Blechnum%20spicant",   
    img_credit = ""
}
magnify.register_plant(Fern, {"default:fern_1", "default:fern_2", "default:fern_3"})