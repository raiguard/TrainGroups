local flib_gui = require("__flib__/gui-lite")

local util = {}

--- @param player LuaPlayer
--- @return ChangeGroupGui?
function util.get_change_group_gui(player)
  local gui = global.change_group_guis[player.index]
  if gui and gui.elems.tgps_select_group_window.valid then
    return gui
  end
end

--- @param player LuaPlayer
--- @return RelativeGui?
function util.get_relative_gui(player)
  local gui = global.relative_guis[player.index]
  if gui and gui.elems.tgps_relative_window.valid then
    return gui
  end
end

--- @param player LuaPlayer
--- @return LuaTrain?
function util.get_open_train(player)
  local opened = player.opened
  if player.opened_gui_type == defines.gui_type.entity and opened and opened.type == "locomotive" then
    return opened.train --[[@as LuaTrain]]
  end
end

--- @param gui table<string, function>
--- @param name string
--- @param wrapper function
function util.add_gui_handlers(gui, name, wrapper)
  local handlers = {}
  for key, val in pairs(gui) do
    handlers[name .. ":" .. key] = val
  end
  flib_gui.add_handlers(handlers, wrapper)
end

return util
