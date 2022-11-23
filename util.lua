local util = {}

--- @param player LuaPlayer
--- @return SelectGroupGui?
function util.get_select_group_gui(player)
  local gui = global.select_group_guis[player.index]
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

return util
