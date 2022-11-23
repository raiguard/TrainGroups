local gui_util = require("__flib__/gui-lite")

local groups = require("__TrainGroups__/groups")
local util = require("__TrainGroups__/util")

--- @class SelectGroupGuiElems
--- @field tgps_select_group_window LuaGuiElement
--- @field textfield LuaGuiElement
--- @field scroll_pane LuaGuiElement

local gui = {}

function gui.init()
  --- @type table<uint, SelectGroupGui>
  global.select_group_guis = {}
end

--- @param player LuaPlayer
--- @param train LuaTrain
function gui.build(player, train)
  --- @type SelectGroupGuiElems
  local elems = gui_util.add(player.gui.screen, {
    type = "frame",
    name = "tgps_select_group_window",
    direction = "vertical",
    caption = { "gui.tgps-select-group" },
    elem_mods = { auto_center = true },
    {
      type = "frame",
      style = "inside_deep_frame",
      direction = "vertical",
      {
        type = "frame",
        style = "subheader_frame",
        {
          type = "textfield",
          name = "textfield",
          style_mods = { horizontally_stretchable = true },
          handler = {
            [defines.events.on_gui_confirmed] = gui.on_confirmed,
            [defines.events.on_gui_text_changed] = gui.on_search_query,
          },
        },
        {
          type = "choose-elem-button",
          name = "icon_selector",
          style = "tool_button",
          style_mods = { padding = 0 },
          tooltip = { "gui.tgps-choose-icon" },
          elem_type = "signal",
          signal = { type = "virtual", name = "tgps-signal-icon-selector" },
          handler = {
            [defines.events.on_gui_elem_changed] = gui.add_icon,
          },
        },
      },
      { type = "scroll-pane", name = "scroll_pane", style = "tgps_list_box_scroll_pane" },
    },
  })

  elems.textfield.focus()

  --- @class SelectGroupGui
  local self = {
    elems = elems,
    player = player,
    query = "",
    train = train,
  }
  global.select_group_guis[player.index] = self

  gui.update_list_box(self)
end

--- @param self SelectGroupGui
function gui.destroy(self)
  local window = self.elems.tgps_select_group_window
  if window.valid then
    window.destroy()
  end
  global.select_group_guis[self.player.index] = nil
end

--- @param self SelectGroupGui
function gui.on_confirmed(self)
  local scroll_pane = self.elems.scroll_pane
  if #scroll_pane.children > 0 then
    local group_name = scroll_pane.children[1].tags.group --[[@as string?]]
    gui.select_group(self, group_name)
  else
    gui.select_group(self, self.elems.textfield.text)
  end
end

--- @param self SelectGroupGui
--- @param e on_gui_click
function gui.on_result_click(self, e)
  local group_name = e.element.tags.group --[[@as string?]]
  gui.select_group(self, group_name)
end

--- @param self SelectGroupGui
--- @param e on_gui_text_changed
function gui.on_search_query(self, e)
  self.query = string.lower(e.element.text)
  gui.update_list_box(self)
end

--- @param self SelectGroupGui
--- @param group_name string?
function gui.select_group(self, group_name)
  local train_data = global.trains[self.train.id]
  if train_data and group_name and group_name ~= train_data.group then
    groups.change_train_group(train_data, group_name)
  elseif train_data and not group_name then
    groups.remove_train(train_data)
  elseif group_name and not train_data then
    groups.add_train(self.train, group_name)
  end
  -- Close the train GUI, which will destroy this GUI and re-open the train with the new group
  self.player.opened = nil
end

--- @param self SelectGroupGui
function gui.update_list_box(self)
  local scroll_pane = self.elems.scroll_pane
  scroll_pane.clear()
  local query = self.query
  if #query == 0 then
    gui_util.add(scroll_pane, {
      type = "button",
      style = "tgps_list_box_item",
      caption = { "gui.tgps-no-group" },
      handler = { [defines.events.on_gui_click] = gui.on_result_click },
    })
  end
  for name, group_data in pairs(global.groups[self.player.force.index]) do
    if string.find(string.lower(name), query, nil, true) then
      gui_util.add(scroll_pane, {
        type = "button",
        style = "tgps_list_box_item",
        caption = { "gui.tgps-name-and-count", name, table_size(group_data.trains) },
        tags = { group = name },
        handler = { [defines.events.on_gui_click] = gui.on_result_click },
      })
    end
  end

  if #scroll_pane.children == 0 then
    self.elems.tgps_select_group_window.caption = { "gui.tgps-create-group" }
  else
    self.elems.tgps_select_group_window.caption = { "gui.tgps-select-group" }
  end
end

gui_util.add_handlers({
  sg_on_confirmed = gui.on_confirmed,
  sg_on_result_click = gui.on_result_click,
  sg_on_search_query = gui.on_search_query,
}, function(e, handler)
  local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
  local self = util.get_select_group_gui(player)
  if self then
    handler(self, e)
  end
end)

return gui
