minetest.set_mapgen_setting('mg_name', 'singlenode', true)
minetest.set_mapgen_setting('flags', 'nolight', true)

local c_stone = minetest.get_content_id("default:stone")
local c_water = minetest.get_content_id("default:water_source")
local c_lava = minetest.get_content_id("default:lava_source")
local c_air = minetest.get_content_id("air")
local c_dirt = minetest.get_content_id("default:dirt")
local c_grass = minetest.get_content_id("default:dirt_with_grass")
local c_sand = minetest.get_content_id("default:sand")

local function getTerrainLevel(posX, posZ, seaLevel, mainPerlin, erosionPerlin)
    local noise = mainPerlin:get_2d({ x = posX, y = posZ })
    local noise2 = erosionPerlin:get_2d({ x = posX, y = posZ })
    return seaLevel + (noise * 5) + (noise * noise2 * 20)
end

local function getStoneLevel(posX, posZ, terrainLevel, continentalPerlin)
    local noise = continentalPerlin:get_2d({ x = posX, y = posZ })
    return terrainLevel - (noise * 3) - 5
end


local function getTerrainNode(posX, posY, posZ, seaLevel, seed, mainPerlin, continentalPerlin, erosionPerlin)
    local surfaceLevel = getTerrainLevel(posX, posZ, seaLevel, mainPerlin, erosionPerlin)
    local stoneLevel = getStoneLevel(posX, posZ, surfaceLevel, continentalPerlin)

    if (posY < stoneLevel) then
        return c_stone
    elseif (posY < surfaceLevel) then
        return c_dirt
    elseif (posY < seaLevel) then
        return c_water
    else
        return c_air
    end
end

local function DecorateTerrain(StartPos, EndPos, groundLevel, data, a)
    -- Decorate terrain with grass, sand, etc.
    for z = StartPos.z, EndPos.z do
        for y = StartPos.y, EndPos.y do
            for x = StartPos.x, EndPos.x do
                -- vi, voxel index, is a common variable name here
                local vi = a:index(x, y, z)
                local viAbove = a:index(x, y + 1, z)
                local viBelow = a:index(x, y - 1, z)

                if (y <= groundLevel and data[vi] == c_dirt and (data[viAbove] == c_air or data[viAbove] == c_water)) then
                    data[vi] = c_sand

                    if (data[viBelow] == c_dirt) then
                        data[viBelow] = c_sand
                    end

                end

                if (data[vi] == c_dirt and data[viAbove] == c_air) then
                    data[vi] = c_grass
                end
            end
        end
    end

end

function Realm:GenerateTerrain(seed, seaLevel)

    local perlin = minetest.get_perlin(seed, 4, 0.5, 100)
    local continentality = minetest.get_perlin(seed * 2, 4, 0.5, 400)
    local erosion = minetest.get_perlin(seed * 3, 1, 0.5, 100)

    local vm = minetest.get_voxel_manip()
    local emin, emax = vm:read_from_map(self.StartPos, self.EndPos)
    local a = VoxelArea:new {
        MinEdge = emin,
        MaxEdge = emax
    }

    local data = vm:get_data()

    -- Create base terrain
    for z = self.StartPos.z, self.EndPos.z do
        for y = self.StartPos.y, self.EndPos.y do
            for x = self.StartPos.x, self.EndPos.x do
                -- vi, voxel index, is a common variable name here
                local vi = a:index(x, y, z)
                data[vi] = getTerrainNode(x, y, z, seaLevel, seed, perlin, continentality, erosion)

            end
        end
    end

    DecorateTerrain(self.StartPos, self.EndPos, seaLevel, data, a)

    -- biomegen.generate_biomes(data, a, self.StartPos, self.EndPos, seaLevel)
    vm:set_data(data)



    -- Decorate terrain with trees



    vm:write_to_map()


    -- Set our new spawnpoint
    local oldSpawnPos = self.SpawnPoint
    local surfaceLevel = getTerrainHeight(oldSpawnPos.x, oldSpawnPos.z, seaLevel, perlin, continentality, erosion)

    self:UpdateSpawn(self:WorldToLocalPosition({ x = oldSpawnPos.x, y = surfaceLevel, z = oldSpawnPos.z }))
end