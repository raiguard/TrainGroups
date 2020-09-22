local tsch_gui = {}

local gui = require("__flib__.gui")
local mod_gui = require("__core__.lualib.mod-gui")

gui.add_handlers{
  networks = {
    create_network_button = {
      on_gui_click = function(e)
        local new_index = #global.networks + 1
        global.networks[new_index] = {
          name = "Network "..tostring(new_index),
          schedule = {},
          trains = {}
        }
        local player = game.get_player(e.player_index)
        player.print("CREATED NETWORK ["..new_index.."]")
        tsch_gui.update_network_dropdown(player, global.players[e.player_index])
      end
    },
    -- delete_network_button = {
    --   on_gui_click = function(e)

    --   end
    -- }
  },
  train_popup = {
    network_dropdown = {
      on_gui_selection_state_changed = function(e)
        local player = game.get_player(e.player_index)
        local player_table = global.players[e.player_index]
      end
    }
  }
}

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
        {type = "frame", style = "inside_shallow_frame", direction = "vertical", children = {
          {type = "frame", style = "subheader_frame", children = {
            {type = "empty-widget", style = "flib_horizontal_pusher"},
            {
              type = "sprite-button",
              style = "flib_tool_button_light_green",
              sprite = "utility/add",
              tooltip = {"tsch-gui.create-network"},
              handlers = "networks.create_network_button"
            },
            -- {
            --   type = "sprite-button",
            --   style = "tool_button_red",
            --   sprite = "utility/trash",
            --   tooltip = {"tsch-gui.delete-network"},
            --   handlers = "networks.delete_network_button"
            -- },
          }},
          {type = "scroll-pane", style="flib_naked_scroll_pane", children={
            {type = "flow", style_mods = {vertical_align = "center"}, children = {
              {type = "label", style = "bold_label", caption = "Network:"},
              {type = "empty-widget", style = "flib_horizontal_pusher"},
              {
                type = "drop-down",
                items = (
                  function()
                    local items = {
                      "No network"
                    }
                    for i, data in pairs(global.networks) do
                      items[i + 1] = data.name
                    end
                    return items
                  end
                )(),
                selected_index = 1,
                handlers = "train_popup.network_dropdown"
              }
            }}
          }}
        }}
      }
    }
  })
  gui_data.train = train
  player_table.gui.popup = gui_data
  player_table.flags.gui_open = true
end

function tsch_gui.destroy(player, player_table)
  player_table.flags.gui_open = false
  player_table.gui.popup.window.destroy()
  player_table.gui.popup = nil
end

function tsch_gui.update_network_dropdown(player, player_table)

end

return tsch_gui