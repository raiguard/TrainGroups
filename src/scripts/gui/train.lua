local train_gui = {}

local gui = require("__flib__.gui")
local mod_gui = require("__core__.lualib.mod-gui")

local global_data = require("scripts.global-data")

gui.add_handlers{
  train = {
    network_dropdown = {
      on_gui_selection_state_changed = function(e)
        local player = game.get_player(e.player_index)
        local player_table = global.players[e.player_index]
        local gui_data = player_table.gui.train
        local train = gui_data.train
        local train_data = global.trains[train.id]
        local selected_index = e.element.selected_index

        if train_data then
          if selected_index > 1 then
            global_data.change_train_network(train_data, e.element.items[selected_index])
          else
            global_data.remove_train(train)
          end
        elseif selected_index > 1 then
          global_data.add_train(train, e.element.items[selected_index])
        end
        train_gui.update_network_dropdown(player, player_table)
      end
    }
  }
}

function train_gui.create(player, player_table, locomotive)
  local train = locomotive.train

  local gui_data = gui.build(mod_gui.get_frame_flow(player), {
    {
      type = "frame",
      style = mod_gui.frame_style,
      style_mods = {use_header_filler = false},
      caption = "TEMP",
      save_as = "window",
      children = {
        {type = "frame", style = "inside_shallow_frame_with_padding", direction = "vertical", children = {
          {type = "flow", style_mods = {vertical_align = "center"}, children = {
            {type = "label", style = "bold_label", caption = "Network:"},
            {type = "empty-widget", style = "flib_horizontal_pusher"},
            {
              type = "drop-down",
              items = (
                function()

                end
              )(),
              selected_index = 1,
              handlers = "train.network_dropdown",
              save_as = "network_dropdown"
            }
          }}
        }}
      }
    }
  })
  gui_data.train = train
  player_table.gui.train = gui_data

  train_gui.update_network_dropdown(player, player_table)

  player_table.flags.gui_open = true
  global.opened_locomotives[player.index] = locomotive.unit_number
end

function train_gui.destroy(player, player_table)
  player_table.flags.gui_open = false
  player_table.gui.train.window.destroy()
  player_table.gui.train = nil
  global.opened_locomotives[player.index] = nil
end

function train_gui.update_network_dropdown(player, player_table)
  local gui_data = player_table.gui.train
  local train_data = global.trains[gui_data.train.id]
  local network = train_data and train_data.network
  local items = {
    "No network"
  }
  local selected = 1
  for _, data in pairs(global.networks) do
    local new_index = #items + 1
    items[new_index] = data.name
    if network and data.name == network then
      selected = new_index
    end
  end

  local dropdown = player_table.gui.train.network_dropdown
  dropdown.items = items
  dropdown.selected_index = selected
end

return train_gui