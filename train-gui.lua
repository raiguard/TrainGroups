local flib_gui = require("__flib__/gui-lite")

local change_group_gui = require("__TrainGroups__/change-group-gui")

--- @class TrainGuiModule
local train_gui = {}
--- @class TrainGuiHandlers
local handlers = {
  --- @param self TrainGui
  tr_open_change_group = function(self)
    local cg_gui = change_group_gui.get(self.player.index)
    if cg_gui then
      cg_gui.elems.tgps_change_group_window.bring_to_front()
    else
      change_group_gui.build(self.player, self.train)
    end
  end,
}

flib_gui.add_handlers(handlers, function(e, handler)
  local self = train_gui.get(e.player_index)
  if self then
    handler(self)
  end
end)

function train_gui.init()
  --- @type table<uint, TrainGui>
  global.train_guis = {}
end

--- @param player LuaPlayer
--- @param train LuaTrain
function train_gui.build(player, train)
  train_gui.destroy(player.index) -- Just in case

  local caption = { "gui.tgps-no-group-assigned" }
  local train_data = global.trains[train.id]
  if train_data then
    local group_data = global.groups[train_data.force][train_data.group]
    if group_data then
      caption = {
        "",
        { "gui.tgps-group" },
        ": ",
        { "gui.tgps-name-and-count", train_data.group, table_size(group_data.trains) },
      }
    end
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
          handler = handlers.tr_open_change_group,
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

--- @param player_index uint
function train_gui.destroy(player_index)
  local self = global.train_guis[player_index]
  if not self then
    return
  end
  local window = self.window
  if window and window.valid then
    window.destroy()
  end
  global.train_guis[self.player.index] = nil
end

--- @param player_index uint
function train_gui.get(player_index)
  local pgui = global.train_guis[player_index]
  if pgui and pgui.window.valid then
    return pgui
  end
end

return train_gui
