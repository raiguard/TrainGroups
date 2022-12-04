local flib_gui = require("__flib__/gui-lite")

local groups = require("__TrainGroups__/groups")
local util = require("__TrainGroups__/util")

--- @class SelectGroupGuiElems
--- @field tgps_select_group_window LuaGuiElement
--- @field tgps_select_group_overlay LuaGuiElement
--- @field textfield LuaGuiElement
--- @field textfield_placeholder LuaGuiElement
--- @field scroll_pane LuaGuiElement

local gui = {}

function gui.init()
  --- @type table<uint, ChangeGroupGui>
  global.change_group_guis = {}
end

--- @param player LuaPlayer
--- @param train LuaTrain
function gui.build(player, train)
  local resolution = player.display_resolution
  local scale = player.display_scale
  local overlay_size = { resolution.width / scale, resolution.height / scale }

  --- @type SelectGroupGuiElems
  local elems = flib_gui.add(player.gui.screen, {
    {
      type = "frame",
      name = "tgps_select_group_overlay",
      style = "invisible_frame",
      style_mods = { size = overlay_size },
      handler = { [defines.events.on_gui_click] = gui.destroy },
    },
    {
      type = "frame",
      name = "tgps_select_group_window",
      direction = "vertical",
      elem_mods = { auto_center = true },
      {
        type = "flow",
        style = "flib_titlebar_flow",
        drag_target = "tgps_select_group_window",
        {
          type = "label",
          style = "frame_title",
          caption = { "gui.tgps-change-train-group" },
          ignored_by_interaction = true,
        },
        { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
        {
          type = "sprite-button",
          style = "frame_action_button",
          sprite = "utility/close_white",
          hovered_sprite = "utility/close_black",
          clicked_sprite = "utility/close_black",
          tooltip = { "gui.close-instruction" },
          handler = { [defines.events.on_gui_click] = gui.destroy },
        },
      },
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
              [defines.events.on_gui_text_changed] = gui.update,
            },
            {
              type = "label",
              name = "textfield_placeholder",
              style_mods = { font_color = { 0, 0, 0, 0.4 } },
              caption = { "gui.tgps-no-group" },
              ignored_by_interaction = true,
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
            handler = { [defines.events.on_gui_elem_changed] = gui.add_icon },
          },
          {
            type = "sprite-button",
            style = "flib_tool_button_light_green",
            sprite = "utility/enter",
            tooltip = { "gui.confirm" },
            handler = { [defines.events.on_gui_click] = gui.on_confirmed },
          },
        },
        { type = "scroll-pane", name = "scroll_pane", style = "tgps_list_box_scroll_pane" },
      },
    },
  })

  -- Populate list box
  --- @type GuiElemDef[]
  local items = {
    {
      type = "button",
      style = "tgps_list_box_item",
      caption = { "gui.tgps-no-group" },
      handler = { [defines.events.on_gui_click] = gui.on_result_click },
    },
  }
  for name, group_data in pairs(global.groups[player.force.index]) do
    table.insert(items, {
      type = "button",
      name = name,
      style = "tgps_list_box_item",
      caption = { "gui.tgps-name-and-count", name, table_size(group_data.trains) },
      handler = { [defines.events.on_gui_click] = gui.on_result_click },
    })
  end
  table.sort(items, function(a, b)
    return (a.name or "") < (b.name or "")
  end)
  flib_gui.add(elems.scroll_pane, items)

  elems.textfield.focus()

  --- @class ChangeGroupGui
  local self = {
    elems = elems,
    player = player,
    train = train,
  }
  global.change_group_guis[player.index] = self

  gui.update(self)
end

--- @param self ChangeGroupGui
function gui.destroy(self)
  local window = self.elems.tgps_select_group_window
  if window.valid then
    window.destroy()
  end
  local overlay = self.elems.tgps_select_group_overlay
  if overlay and overlay.valid then
    overlay.destroy()
  end
  global.change_group_guis[self.player.index] = nil
end

--- @param self ChangeGroupGui
function gui.on_confirmed(self)
  gui.select_group(self, self.elems.textfield.text)
end

--- @param self ChangeGroupGui
--- @param e on_gui_click
function gui.on_result_click(self, e)
  gui.select_group(self, e.element.name)
end

--- @param self ChangeGroupGui
--- @param e on_gui_elem_changed
function gui.add_icon(self, e)
  local button = e.element
  local signal = button.elem_value
  if signal and signal.name ~= "tgps-signal-icon-selector" then
    local textfield = self.elems.textfield
    local type = signal.type == "virtual" and "virtual-signal" or signal.type
    textfield.text = textfield.text .. "[img=" .. type .. "/" .. signal.name .. "]"
    textfield.select(#textfield.text + 1, #textfield.text)
    textfield.focus()
    gui.update(self)
  end
  button.elem_value = { type = "virtual", name = "tgps-signal-icon-selector" }
end

--- @param self ChangeGroupGui
--- @param group_name string?
function gui.select_group(self, group_name)
  if #group_name == 0 then
    group_name = nil
  end
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

--- @param self ChangeGroupGui
function gui.update(self)
  local query = string.lower(self.elems.textfield.text)
  -- Textfield
  self.elems.textfield_placeholder.visible = not (#query > 0)
  -- List box
  for _, item in pairs(self.elems.scroll_pane.children) do
    local group = item.name
    if #group > 0 then
      item.visible = string.find(string.lower(group), query, nil, true) --[[@as boolean]]
    else
      item.visible = #query == 0
    end
  end
end

util.add_gui_handlers(gui, "change_group", function(e, handler)
  local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
  local self = util.get_change_group_gui(player)
  if self then
    handler(self, e)
  end
end)

return gui
