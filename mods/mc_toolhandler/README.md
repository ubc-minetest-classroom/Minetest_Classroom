# mc_toolhandler

Provides functionality for giving/taking classroom tools from players.

All tools handled by `mc_toolhandler` will automatically be given to players with adequate usage privileges for them, and automatically be taken away from players who lose the privileges necessary to use them.

## Tool definition fields used by `mc_toolhandler`

`mc_toolhandler` manages tools for all mods specified in the `optional_depends` of its `mod.conf` file. A tool will be managed by `mc_toolhandler` if it contains at least one of the following properties in its tool definition:

- `_mc_tool_privs`: A table of privileges required to use the tool, or an empty table if no priviliges are required to use the tool.
  - Usage: ```_mc_tool_privs = {interact = true, fly = true}```
- `_mc_tool_include`: Boolean flag indicating whether `mc_toolhandler` should manage the tool.
  - If `_mc_tool_include = true` and no `_mc_tool_privs` are set, tool usage privileges default to `{teacher = true}`.
  - If `_mc_tool_include = false`, `mc_toolhander` will not manage the tool.

Additional properties need to be set for groups of similar tools (ex. a tool with changing textures registered as multiple tools):

- `_mc_tool_group`: A group name for the tool, used to detect the presence of the tool instead of the tool name.
  - Usage: ```_mc_tool_group = "modname:generic_tool_name"```

The following properties are optional:

- `_mc_tool_allow_take`: Boolean flag indicating whether tool can be taken out of the player inventory. If unspecified, treated as `false`.

## Managing tools using `mc_toolhandler`

To add tools to the list of tools handled by `mc_toolhandler`, follow the steps below:

- Add the name of the mod containg the tools you wish to manage (as defined in the mod's `mod.conf` file) to the `optional_depends` line of `mc_toolhandler`'s `mod.conf` file
  - `optional_depends` is a comma-separated list, so ensure that each mod in the list is separated by a comma
- Define the `_mc_tool_privs` and/or `_mc_tool_include` fields in the tool definition for each tool you want `mc_toolhandler` to manage, as specified above
- If applicable, define the `_mc_tool_group` field for any tools that need it as specified above
- Define optional properties for each tool as specified above, if desired
