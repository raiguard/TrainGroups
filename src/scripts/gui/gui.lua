local tsch_gui = {}

local gui = require("__flib__.gui")
local mod_gui = require("__core__.lualib.mod-gui")

-- TODO rename `gui` subtable to something else

function tsch_gui.create(player, player_table, train)
  local gui_data = gui.build(mod_gui.get_frame_flow(player), {
    {
      type = "frame",
      style = mod_gui.frame_style,
      style_mods = {use_header_filler = false},
      caption = "TEMP",
      save_as = "window",
      children = {
        {type = "frame", style = "inside_shallow_frame_with_padding", children = {
          {type = "label", caption = "Hello, world!"}
        }}
      }
    }
  })
  gui_data.train = train
  player_table.gui.gui = gui_data
  player_table.flags.gui_open = true
end

function tsch_gui.destroy(player, player_table)
  player_table.flags.gui_open = false
  player_table.gui.gui.window.destroy()
  player_table.gui.gui = nil
end

return tsch_gui