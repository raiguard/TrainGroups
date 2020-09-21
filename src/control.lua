local event = require("__flib__.event")
local migration = require("__flib__.migration")

-- -----------------------------------------------------------------------------
-- EVENT HANDLERS

-- BOOTSTRAP

event.on_init(function()

end)

event.on_load(function()
end)

event.on_configuration_changed(function(e)
  if migration.on_config_changed(e, {}) then

  end
end)

-- PLAYER

event.on_player_created(function(e)

end)

event.on_player_joined_game(function(e)

end)

event.on_player_left_game(function(e)

end)

event.on_player_removed(function(e)

end)