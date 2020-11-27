local gui = require("__flib__.gui-beta")
local train_util = require("__flib__.train")

local global_data = require("scripts.global-data")

local train_gui = {}

function train_gui.create(player, player_table)
  local refs = gui.build(player.gui.relative, {
    {
      type = "frame",
      caption = {"tgps-gui.groups"},
      anchor = {
        gui = defines.relative_gui_type.train_gui,
        position = defines.relative_gui_position.left
      },
      ref = {"window"},
      children = {
        {type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical", children = {
          {type = "flow", style_mods = {vertical_align = "center"}, children = {
            {type = "label", style = "caption_label", style_mods = {right_margin = 8}, caption = {"tgps-gui.group-label"}},
            {type = "drop-down", items = {}, ref = {"group_dropdown"}, actions = {on_selection_state_changed = {gui = "train", action = "change_train_group"}}}
          }}
        }}
      }
    }
  })

  player_table.gui.train = {
    refs = refs,
    state = {}
  }
end

function train_gui.destroy(player_table)
  player_table.gui.train.refs.window.destroy()
  player_table.gui.train = nil
end

function train_gui.update_group_dropdown(player, player_table)
  local gui_data = player_table.gui.train
  local train_data = global.trains[gui_data.state.train.id]
  local group = train_data and train_data.group
  local items = {
    {"tgps-gui.select-a-group"}
  }
  local selected = 1
  for _, data in pairs(global.groups[train_util.get_main_locomotive(gui_data.state.train).force.index]) do
    local new_index = #items + 1
    items[new_index] = data.name
    if group and data.name == group then
      selected = new_index
    end
  end

  local dropdown = gui_data.refs.group_dropdown
  dropdown.items = items
  dropdown.selected_index = selected
end

function train_gui.handle_action(e, msg)
  local player = game.get_player(e.player_index)
  local player_table = global.players[e.player_index]
  local gui_data = player_table.gui.train

  if msg.action == "set_train" then
    gui_data.state.train = msg.train
    train_gui.update_group_dropdown(player, player_table)
  elseif msg.action == "change_train_group" then
    local train = gui_data.state.train
    local train_data = global.trains[train.id]
    local selected_index = e.element.selected_index

    if train_data then
      if selected_index > 1 then
        global_data.change_train_group(train_data, e.element.items[selected_index])
      else
        global_data.remove_train(train_data)
      end
    elseif selected_index > 1 then
      global_data.add_train(train, e.element.items[selected_index])
    end
  end
end

return train_gui