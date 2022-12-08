local flib_gui = require("__flib__/gui-lite")

local change_group_gui = require("__TrainGroups__/change-group-gui")
local util = require("__TrainGroups__/util")

--- @class TrainGuiModule
local gui = {}

function gui.init()
  --- @type table<uint, TrainGui>
  global.train_guis = {}
end

--- @param player LuaPlayer
--- @param train LuaTrain
function gui.build(player, train)
  local caption = { "gui.tgps-no-group-assigned" }
  local train_data = global.trains[train.id]
  if train_data then
    local group_data = global.groups[train_data.force][train_data.group]
    caption =
      { "", { "gui.tgps-group" }, ": ", { "gui.tgps-name-and-count", train_data.group, table_size(group_data.trains) } }
  end

  local _, window = flib_gui.add(player.gui.relative, {
    {
      type = "frame",
      name = "tgps_train_window",
      style = "quick_bar_window_frame",
      -- Relative GUI will stretch top frames by default for some reason
      style_mods = { horizontally_stretchable = false },
      anchor = { gui = defines.relative_gui_type.train_gui, position = defines.relative_gui_position.top },
      {
        type = "frame",
        style = "inside_deep_frame",
        {
          type = "button",
          style = "tgps_relative_group_button",
          caption = caption,
          tooltip = { "gui.tgps-change-train-group" },
          handler = { [defines.events.on_gui_click] = gui.open_change_group },
        },
      },
    },
  })

  --- @class TrainGui
  local self = {
    player = player,
    train = train,
    window = window,
  }
  global.train_guis[player.index] = self
end

--- @param self TrainGui
function gui.destroy(self)
  local window = self.window
  if window and window.valid then
    window.destroy()
  end
  global.train_guis[self.player.index] = nil
end

--- @param player_index uint
function gui.get(player_index)
  local pgui = global.train_guis[player_index]
  if pgui and pgui.window.valid then
    return pgui
  end
end

--- @param self TrainGui
function gui.open_change_group(self)
  local cg_gui = change_group_gui.get(self.player.index)
  if cg_gui then
    cg_gui.elems.tgps_change_group_window.bring_to_front()
  else
    change_group_gui.build(self.player, self.train)
  end
end

util.add_gui_handlers(gui, "relative", function(e, handler)
  local self = gui.get(e.player_index)
  if self then
    handler(self)
  end
end)

return gui
