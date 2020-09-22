local event = require("__flib__.event")
local gui = require("__flib__.gui")
local migration = require("__flib__.migration")

local global_data = require("scripts.global-data")
local player_data = require("scripts.player-data")
local train_gui = require("scripts.gui.train")

-- -----------------------------------------------------------------------------
-- EVENT HANDLERS

-- BOOTSTRAP

event.on_init(function()
  gui.init()
  gui.build_lookup_tables()

  global_data.init()

  for i in pairs(game.players) do
    player_data.init(i)
  end
end)

event.on_load(function()
  gui.build_lookup_tables()
end)

event.on_configuration_changed(function(e)
  if migration.on_config_changed(e, {}) then
    gui.check_filter_validity()
  end
end)

-- GUI

gui.register_handlers()

event.on_gui_opened(function(e)
  if not gui.dispatch_handlers(e) then
    if e.entity and e.entity.type == "locomotive" then
      train_gui.create(game.get_player(e.player_index), global.players[e.player_index], e.entity)
    end
  end
end)

event.on_gui_closed(function(e)
  if not gui.dispatch_handlers(e) then
    local player_table = global.players[e.player_index]
    if player_table.flags.gui_open then
      train_gui.destroy(game.get_player(e.player_index), player_table)
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

-- TRAIN

event.on_train_created(function(e)
  if e.old_train_id_1 or e.old_train_id_2 then
    global_data.migrate_trains(e.train, e.old_train_id_1, e.old_train_id_2)
  end
end)

event.register(
  {
    defines.events.on_player_mined_entity,
    defines.events.on_robot_mined_entity,
    defines.events.on_entity_died,
    defines.events.script_raised_destroy
  },
  function(e)
    local entity = e.entity
    local unit_number = entity.unit_number or -1
    for player_index, entity_number in pairs(global.opened_locomotives) do
      if entity_number == unit_number then
        train_gui.destroy(game.get_player(player_index), global.players[player_index])
      end
    end
  end
)