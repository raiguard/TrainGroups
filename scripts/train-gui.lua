local flib_gui = require("__flib__/gui-lite")

local change_group_gui = require("__TrainGroups__/scripts/change-group-gui")
local util = require("__TrainGroups__/scripts/util")

--- @param self TrainGui
--- @param train LuaTrain?
local function update(self, train)
  if train then
    self.train = train
    self.train_id = train.id
  end
  local caption = { "gui.tgps-no-group-assigned" }
  local train_data = global.trains[self.train.id]
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
  self.button.caption = caption
end

--- @param self TrainGui
local function open_change_group_gui(self)
  change_group_gui.open(self.player, self.train)
end

--- @param player_index uint
local function destroy_gui(player_index)
  local self = global.train_guis[player_index]
  if not self then
    return
  end
  local window = self.window
  if window and window.valid then
    window.destroy()
  end
  global.train_guis[player_index] = nil
end

--- @param player LuaPlayer
--- @param train LuaTrain
--- @return TrainGui
local function build_gui(player, train)
  destroy_gui(player.index)

  local elems = flib_gui.add(player.gui.relative, {
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
          name = "button",
          style = "tgps_relative_group_button",
          tooltip = { "gui.tgps-change-train-group" },
          handler = open_change_group_gui,
        },
      },
    },
  })

  --- @class TrainGui
  local self = {
    button = elems.button,
    player = player,
    train_id = train.id,
    train = train,
    window = elems.tgps_train_window,
  }
  global.train_guis[player.index] = self

  return self
end

--- @param e on_update_train_gui
local function on_update_train_gui(e)
  local self = global.train_guis[e.player_index]
  if self and self.window.valid then
    update(self)
  end
end

--- @param e EventData.on_gui_opened
local function on_gui_opened(e)
  local entity = e.entity
  if e.gui_type ~= defines.gui_type.entity then
    return
  end
  if not entity or not entity.valid or entity.type ~= "locomotive" then
    return
  end
  local train = entity.train
  if not train then
    return
  end
  local player = game.get_player(e.player_index)
  if not player then
    return
  end
  local self = global.train_guis[e.player_index]
  if not self then
    self = build_gui(player, entity.train)
  end
  update(self, entity.train)
end

--- @param e EventData.on_train_created
local function on_train_created(e)
  if not global.train_guis then
    return
  end
  if not e.old_train_id_1 and not e.old_train_id_2 then
    return
  end
  for _, self in pairs(global.train_guis) do
    if self.train.valid then
      goto continue
    end
    if self.train_id == e.old_train_id_1 or self.train_id == e.old_train_id_2 then
      update(self, e.train)
    end
    ::continue::
  end
end

--- @class TrainGuiMod
local train_gui = {}

function train_gui.on_init()
  --- @type table<uint, TrainGui>
  global.train_guis = {}
end

function train_gui.on_configuration_changed()
  for player_index in pairs(global.train_guis) do
    destroy_gui(player_index)
  end
end

train_gui.events = {
  [defines.events.on_gui_opened] = on_gui_opened,
  [defines.events.on_train_created] = on_train_created,
  [util.update_train_gui_event] = on_update_train_gui,
}

flib_gui.add_handlers({ tr_open_change_group_gui = open_change_group_gui }, function(e, handler)
  local self = global.train_guis[e.player_index]
  if self then
    handler(self)
  end
end)

return train_gui
