local event = require("__flib__.event")
local gui_util = require("__flib__.gui")
local migration = require("__flib__.migration")

local gui = require("gui")
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

gui_util.hook_events(function(e)
  local action = gui_util.read_action(e)
  if action then
    local player = game.get_player(e.player_index)
    -- We probably don't need all of these checks, but you can't be too safe
    if player.opened_gui_type == defines.gui_type.entity and player.opened and player.opened.type == "locomotive" then
      gui[action](e.element, player.opened.train)
    end
  end
end)

event.on_gui_opened(function(e)
  if e.gui_type == defines.gui_type.entity and e.entity and e.entity.type == "locomotive" then
    gui.build(game.get_player(e.player_index), e.entity.train)
  end
end)

event.on_gui_closed(function(e)
  if e.gui_type == defines.gui_type.entity and e.entity and e.entity.type == "locomotive" then
    gui.destroy(game.get_player(e.player_index))
  end
end)

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
