local gui_util = require("__flib__/gui-lite")

local select_group_gui = require("__TrainGroups__/select-group-gui")
local util = require("__TrainGroups__/util")

--- @class RelativeGuiElems
--- @field tgps_relative_window LuaGuiElement
--- @field relative_button LuaGuiElement

local gui = {}

function gui.init()
  global.relative_guis = {}
end

--- @param player LuaPlayer
--- @param train LuaTrain
function gui.build(player, train)
  --- @type RelativeGuiElems
  local elems = gui_util.add(player.gui.relative, {
    {
      type = "frame",
      name = "tgps_relative_window",
      style = "quick_bar_window_frame",
      -- Relative GUI will stretch top frames by default for some reason
      style_mods = { horizontally_stretchable = false },
      anchor = { gui = defines.relative_gui_type.train_gui, position = defines.relative_gui_position.top },
      {
        type = "frame",
        style = "inside_deep_frame",
        {
          type = "button",
          name = "relative_button",
          style = "tgps_relative_group_button",
          handler = {
            [defines.events.on_gui_click] = gui.open_select_group,
          },
        },
      },
    },
  })

  --- @class RelativeGui
  local self = {
    elems = elems,
    player = player,
    train = train,
  }
  global.relative_guis[player.index] = self

  gui.update_caption(self)
end

--- @param self RelativeGui
function gui.destroy(self)
  local window = self.elems.tgps_relative_window
  if window and window.valid then
    window.destroy()
  end
  global.relative_guis[self.player.index] = nil
end

-- TODO: This might be unnecessary, since the GUI will be closed and reopened anyway
--- @param self RelativeGui
function gui.update_caption(self)
  local button = self.elems.relative_button
  local train_data = global.trains[self.train.id]
  if train_data then
    local group_data = global.groups[train_data.force][train_data.group]
    button.caption =
      { "", { "gui.tgps-group" }, ": ", { "gui.tgps-name-and-count", train_data.group, table_size(group_data.trains) } }
  else
    button.caption = { "gui.tgps-no-group" }
  end
end

--- @param self RelativeGui
function gui.open_select_group(self)
  local sg_gui = util.get_select_group_gui(self.player)
  if sg_gui then
    sg_gui.elems.tgps_select_group_window.bring_to_front()
  else
    select_group_gui.build(self.player, self.train)
  end
end

gui_util.add_handlers(
  { relative_open_select_group = gui.open_select_group, relative_update_caption = gui.update_caption },
  function(e, handler)
    local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
    local self = util.get_relative_gui(player)
    if self then
      handler(self)
    end
  end
)

return gui
