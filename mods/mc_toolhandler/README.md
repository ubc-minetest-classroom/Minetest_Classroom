# mc_toolhandler

Provides functionality for automatically managing player tools based on player privileges.

All tools handled by `mc_toolhandler` will automatically be given to players with adequate usage privileges for them, and automatically be taken away from players who lose the privileges necessary to use them.  
Players can only hold one copy of each managed tool in their player inventory at a time.

## API

### `mc_toolhandler.register_tool_manager(tool, options)  -->  boolean`

Registers `tool` to be managed by `mc_toolhandler`

- Parameters:
  - `tool` (*`string`*): Name of tool to be managed
  - `options` (*`table`*): Table of tool options - defaults are given below

  ```lua
  local options = {
      privs = {teacher = true},   -- Table of privileges necessary to use the tool
      allow_take = false          -- Whether the tool is allowed to be taken out of the player inventory or not
  }
  ```
  
- Usage:

  ```lua
  mc_toolhandler.register_tool_manager("mod:tool", options)
  ```

- Returns:
  - *`boolean`*: `true` if the tool was successfully registered, `false` otherwise

### `mc_toolhandler.register_group_manager(tools, options)  -->  boolean`

Registers a group of similar tools to be managed by `mc_toolhandler` as if they were one tool

- Parameters:
  - `tools` (*`table`*): Table of itemstrings of tools to be managed
  - `options` (*`table`*): Table of tool options - defaults are given below

  ```lua
  local options = {
      privs = {teacher = true},   -- Table of privileges necessary to use the tool
      allow_take = false,         -- Whether the tool is allowed to be taken out of the player inventory or not
      default_tool = tools[1]     -- Group member to treat as the "primary" tool instance and give by default
  }
  ```
  
- Usage:

  ```lua
  mc_toolhandler.register_group_manager({"mod:tool", "mod:different_tool", "another_mod:other_tool"}, options)
  ```

- Returns:
  - *`boolean`*: `true` if the tool group was successfully registered, `false` otherwise

### `mc_toolhandler.create_tool_inventory(player)  -->  InvRef, string, string`

Returns a detached inventory containing all tools `player` has the privileges to use, which `player` can freely take copies of as desired  
It is recommended to call this every time access to the detached inventory is needed in case player privileges change between uses

- Parameters:
  - `player` (*`ObjectRef`*): Player to generate the detached inventory for
- Returns:
  - *`InvRef`*: Detached inventory containing all tools `player` has the privileges to use
  - *`string`*: Name of detached inventory
  - *`string`*: Name of list containing the tools
