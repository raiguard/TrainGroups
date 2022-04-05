local event = require("__flib__.event")
local gui = require("__flib__.gui")
local migration = require("__flib__.migration")

local groups = require("groups")

-- -----------------------------------------------------------------------------
-- EVENT HANDLERS

-- BOOTSTRAP

event.on_init(function()
  groups.init()

  for _, force in pairs(game.forces) do
    groups.init_force(force)
  end
end)

event.on_configuration_changed(function(e)
  if migration.on_config_changed(e, {}) then
  end
end)

-- FORCE

event.on_force_created(function(e)
  groups.init_force(e.force)
end)

-- GUI

gui.hook_events(function(e) end)

-- PLAYER

event.on_player_created(function(e) end)

-- TRAIN

event.on_train_created(function(e)
  if e.old_train_id_1 or e.old_train_id_2 then
    groups.migrate_trains(e.train, e.old_train_id_1, e.old_train_id_2)
  end
end)

event.on_train_schedule_changed(function(e)
  groups.update_group_schedule(e.train)
end)
