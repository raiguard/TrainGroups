local player_data = {}

function player_data.init(player_index)
  global.players[player_index] = {
    flags = {
      gui_open = false
    },
    gui = {}
  }
end

return player_data