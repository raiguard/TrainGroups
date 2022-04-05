local event = require("__flib__.event")
local gui = require("__flib__.gui-beta")
local migration = require("__flib__.migration")

local global_data = require("scripts.global-data")
local player_data = require("scripts.player-data")
local train_gui = require("scripts.gui.train")

-- -----------------------------------------------------------------------------
-- EVENT HANDLERS

-- BOOTSTRAP

event.on_init(function()
  global_data.init()

  for _, force in pairs(game.forces) do
    global_data.init_force(force)
  end

  for i in pairs(game.players) do
    player_data.init(i)
    player_data.refresh(game.get_player(i), global.players[i])
  end
end)

event.on_configuration_changed(function(e)
  if migration.on_config_changed(e, {}) then
  end
end)

-- FORCE

event.on_force_created(function(e)
  global_data.init_force(e.force)
end)

-- GUI

gui.hook_events(function(e)
  local msg
  if e.gui_type == defines.gui_type.entity and e.entity.type == "locomotive" then
    msg = {
      gui = "train",
      action = "set_train",
      train = e.entity.train,
    }
  else
    msg = gui.read_action(e)
  end

  if msg then
    if msg.gui == "train" then
      train_gui.handle_action(e, msg)
    end
  end
end)

-- PLAYER

event.on_player_created(function(e)
  player_data.init(e.player_index)
  player_data.refresh(game.get_player(e.player_index), global.players[e.player_index])
end)

event.on_player_joined_game(function(e) end)

event.on_player_left_game(function(e) end)

event.on_player_removed(function(e) end)

-- TRAIN

event.on_train_created(function(e)
  if e.old_train_id_1 or e.old_train_id_2 then
    global_data.migrate_trains(e.train, e.old_train_id_1, e.old_train_id_2)
  end
end)

event.on_train_schedule_changed(function(e)
  global_data.update_group_schedule(e.train)
end)
