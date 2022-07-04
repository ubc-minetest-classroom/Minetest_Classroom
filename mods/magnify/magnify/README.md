# magnify

Adds a magnifying glass tool and inventory plant compenium for viewing information about various plant species in the MineTest world

*Release version: n/a*  
*Dependencies: [`sfinv`](https://github.com/rubenwardy/sfinv)*

## API

### Registration

#### `magnify.register_plant(def_table, nodes)  -->  nil`

Registers a plant species in the `magnify` plant database

- Parameters:
  - `def_table` (*`table`*): Plant species definition table

    ```lua
    local def_table = {
        sci_name = "",        -- Scientific name of species
        com_name = "",        -- Common name of species
        fam_name = "",        -- Family name of species
        cons_status = "",     -- Conservation status of species
        status_col = "",      -- Hex colour of status box ("#000000")
        height = "",          -- Plant height
        bloom = "",           -- The way the plant blooms
        region = "",          -- Native region/range of plant (displayed as "Found in [region]")
        texture = "",         -- Image of plant (in `mod/textures`)
        model_obj = "",       -- Model file (in `mod/models`)
        model_spec = "",      -- Model texture list, as a single string (format may change)
        more_info = "",       -- Description of plant
        external_link = "",   -- Link to page with more plant information
        img_copyright = "",   -- Copyright owner of plant image (displayed as "Image (c) [img_copyright]")
        img_credit = ""       -- Author of plant image (displayed as "Image courtesy of [img_credit]")
    }
    ```

  - `nodes` (*`table`*): Table of stringified nodes (`mod_name:node_name`) the species corresponds to in the MineTest world
- Usage:

  ```lua
  magnify.register_plant(def_table, {"mod:node", "mod:another_node", "other_mod:other_node"})
  ```

#### `magnify.clear_nodes(nodes)  -->  nil`

Clears the nodes in `nodes` from the `magnify` plant database, then clears any plants species that are no longer associated with any nodes as a result of clearing the nodes in `nodes`

- Parameters:
  - `nodes` (*`table`*): Table of stringified nodes (`mod_name:node_name`) to clear

#### `magnify.clear_ref(ref)  -->  nil`

Clears a plant species and all its associated nodes from the `magnify` plant database

- Parameters:
  - `ref` (*`string`*): Reference key of the plant species to clear

### General

#### `magnify.get_ref(node)  -->  string`

Returns the reference key associated with `node` in the `magnify` plant database

- Parameters:
  - `node` (*`string`*): Stringified node (`mod_name:node_name`)
- Returns:
  - *`string`*: Reference key of the node  
  *OR*
  - `nil` if `node` is invalid or not registered in the `magnify` plant database

#### `magnify.get_species_from_ref(ref)  -->  table, table`

Returns the plant definition table the species indexed at `ref` in the `magnify` plant database, and a list of nodes the species is associated with

- Parameters:
  - `ref` (*`string`*): Reference key of the plant species
- Returns:
  - *`table`*: Plant species definition table
  - *`table`*: Table of all nodes associated with the plant species  
  *OR*
  - `nil` if `ref` is invalid

#### `magnify.get_all_registered_species()  -->  table, table`

Returns a human-readable list of all species registered in the `magnify` plant database, and a list of reference keys corresponding to them  
Each species and its corresponding reference key will be at the same index in both lists

- Returns:
  - *`table`*: Names of all registered plant species, formatted as "Common name (Scientific name)"
  - *`table`*: Reference keys for all registered plant species, in the same order as the list of names

#### `magnify.build_formspec_from_ref(ref, is_exit, is_inv)  -->  string, string`

Builds the general plant information formspec for the species indexed at `ref` in the `magnify` plant database  

- Parameters:
  - `ref` (*`string`*): Reference key of the plant species
  - `is_exit` (*`boolean`*): `true` if clicking the "Back" button should exit the formspec, `false` otherwise
  - `is_inv` (*`boolean`*): `true` if the formspec is being used in the player inventory, `false` otherwise
- Returns:
  - *`string`*: Full formspec
  - *`string`*: Formspec `size[]` element  
  *OR*
  - `nil` if `ref` is invalid

### Utility

#### `magnify.table_has(table, val)  -->  boolean`

Returns `true` if any of the keys or values in `table` match `val`, `false` otherwise

- Parameters:
  - `table` (*`table`*): The table to check
  - `val` (*`any`*): The key/value to check for
- Returns:
  - *`boolean`*: Whether `val` exists in `table` or not
