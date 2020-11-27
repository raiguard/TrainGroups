local train_gui = require("scripts.gui.train")

local player_data = {}

function player_data.init(player_index)
  global.players[player_index] = {
    flags = {},
    gui = {},
    settings = {}
  }
end

function player_data.refresh(player, player_table)
  -- TODO: update settings

  if player_table.gui.train then
    train_gui.destroy(player_table)
  end
  train_gui.create(player, player_table)
end

return player_data