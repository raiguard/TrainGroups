local event = require("__flib__.event")
local gui = require("__flib__.gui")
local migration = require("__flib__.migration")

local global_data = require("scripts.global-data")
local player_data = require("scripts.player-data")
local tsch_gui = require("scripts.gui.gui")

-- -----------------------------------------------------------------------------
-- EVENT HANDLERS

-- BOOTSTRAP

event.on_init(function()
  global_data.init()

  for i in pairs(game.players) do
    player_data.init(i)
  end
end)

event.on_load(function()
end)

event.on_configuration_changed(function(e)
  if migration.on_config_changed(e, {}) then

  end
end)

-- GUI

gui.register_handlers()

event.on_gui_opened(function(e)
  if not gui.dispatch_handlers(e) then
    if e.entity and e.entity.type == "locomotive" then
      tsch_gui.create(game.get_player(e.player_index), global.players[e.player_index], e.entity.train)
    end
  end
end)

event.on_gui_closed(function(e)
  if not gui.dispatch_handlers(e) then
    local player_table = global.players[e.player_index]
    if player_table.flags.gui_open then
      tsch_gui.destroy(game.get_player(e.player_index), player_table)
    end
  end
end)


-- PLAYER

event.on_player_created(function(e)
  player_data.init(e.player_index)
end)

event.on_player_joined_game(function(e)

end)

event.on_player_left_game(function(e)

end)

event.on_player_removed(function(e)

end)