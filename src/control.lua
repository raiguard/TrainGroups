local event = require("__flib__.event")
local gui = require("__flib__.gui")
local migration = require("__flib__.migration")

local global_data = require("scripts.global-data")

-- -----------------------------------------------------------------------------
-- EVENT HANDLERS

-- BOOTSTRAP

event.on_init(function()
  global_data.init()

  for _, force in pairs(game.forces) do
    global_data.init_force(force)
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

gui.hook_events(function(e) end)

-- PLAYER

event.on_player_created(function(e) end)

-- TRAIN

event.on_train_created(function(e)
  if e.old_train_id_1 or e.old_train_id_2 then
    global_data.migrate_trains(e.train, e.old_train_id_1, e.old_train_id_2)
  end
end)

event.on_train_schedule_changed(function(e)
  global_data.update_group_schedule(e.train)
end)
