local handler = require("__core__/lualib/event_handler")

handler.add_libraries({
  require("__flib__/gui-lite"),
  require("__TrainGroups__/scripts/change-group-gui"),
  require("__TrainGroups__/scripts/groups"),
  require("__TrainGroups__/scripts/migrations"),
  require("__TrainGroups__/scripts/overview-gui"),
  require("__TrainGroups__/scripts/train-gui"),
})

--- @diagnostic disable
local rolling_stock_filter = { { filter = "rolling-stock" } }
script.set_event_filter(defines.events.on_built_entity, rolling_stock_filter)
script.set_event_filter(defines.events.on_built_entity, rolling_stock_filter)
script.set_event_filter(defines.events.on_entity_cloned, rolling_stock_filter)
script.set_event_filter(defines.events.on_entity_died, rolling_stock_filter)
script.set_event_filter(defines.events.on_player_mined_entity, rolling_stock_filter)
script.set_event_filter(defines.events.on_robot_built_entity, rolling_stock_filter)
script.set_event_filter(defines.events.on_robot_mined_entity, rolling_stock_filter)
script.set_event_filter(defines.events.script_raised_built, rolling_stock_filter)
script.set_event_filter(defines.events.script_raised_destroy, rolling_stock_filter)
script.set_event_filter(defines.events.script_raised_revive, rolling_stock_filter)
