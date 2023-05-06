local flib_gui = require("__flib__/gui-lite")
local flib_train = require("__flib__/train")

local groups = require("__TrainGroups__/scripts/groups")

--- @class OverviewGuiElems
--- @field tgps_overview_window LuaGuiElement
--- @field search_textfield LuaGuiElement
--- @field scroll_pane LuaGuiElement
--- @field no_groups_flow LuaGuiElement

--- @class OverviewGuiMod
local overview_gui = {}
--- @class OverviewGuiHandlers
local handlers

--- @param self OverviewGui
local function refresh(self)
  -- List box
  --- @type GuiElemDef[]
  local items = {}
  for name, group_data in pairs(global.groups[self.player.force.index]) do
    local caption = { "gui.tgps-name-and-count", name, table_size(group_data.trains) }
    table.insert(items, {
      type = "flow",
      name = name,
      style_mods = { horizontal_spacing = 0 },
      {
        type = "flow",
        name = "standard",
        style_mods = { horizontal_spacing = 0 },
        {
          type = "button",
          name = "group_button",
          style = "tgps_list_box_item",
          caption = caption,
          tooltip = { "", "[font=default-semibold]", caption, "[/font]\n", { "gui.tgps-click-to-edit-schedule" } },
          tags = { group = name },
          handler = handlers.ov_edit_schedule,
        },
        {
          type = "sprite-button",
          style = "tool_button",
          sprite = "utility/rename_icon_normal",
          tooltip = { "gui.tgps-rename-group" },
          handler = handlers.ov_start_rename,
        },
        {
          type = "sprite-button",
          style = "tool_button_red",
          sprite = "utility/trash",
          tooltip = { "gui.tgps-remove-group" },
          tags = { group = name },
          handler = handlers.ov_remove_group,
        },
      },
      {
        type = "flow",
        name = "rename",
        style_mods = { horizontal_spacing = 0 },
        visible = false,
        {
          type = "textfield",
          name = "textfield",
          style = "flib_widthless_textfield",
          style_mods = { horizontally_stretchable = true },
          text = name,
          tags = { group = name },
          handler = { [defines.events.on_gui_confirmed] = handlers.ov_rename_group },
        },
        {
          type = "choose-elem-button",
          name = "icon_selector",
          style = "tool_button",
          style_mods = { padding = 0 },
          tooltip = { "gui.tgps-choose-icon" },
          elem_type = "signal",
          signal = { type = "virtual", name = "tgps-signal-icon-selector" },
          handler = { [defines.events.on_gui_elem_changed] = handlers.ov_add_icon },
        },
        {
          type = "sprite-button",
          style = "flib_tool_button_light_green",
          sprite = "utility/enter",
          tooltip = { "gui.confirm" },
          tags = { group = name },
          handler = handlers.ov_rename_group,
        },
      },
    })
  end
  table.sort(items, function(a, b)
    return (a.name or "") < (b.name or "")
  end)
  local scroll_pane = self.elems.scroll_pane
  scroll_pane.clear()
  local no_groups_flow = self.elems.no_groups_flow
  if #items > 0 then
    scroll_pane.visible = true
    no_groups_flow.visible = false
    flib_gui.add(scroll_pane, items)
    handlers.ov_filter(self)
  else
    scroll_pane.visible = false
    no_groups_flow.visible = true
  end
end

--- @class OverviewGuiHandlers
handlers = {
  --- @param e EventData.on_gui_elem_changed
  ov_add_icon = function(_, _, e)
    local button = e.element
    local signal = button.elem_value
    if signal and signal.name ~= "tgps-signal-icon-selector" then
      local textfield = button.parent.textfield or button.parent.search_textfield --[[@as LuaGuiElement]]
      local type = signal.type == "virtual" and "virtual-signal" or signal.type
      textfield.text = textfield.text .. "[img=" .. type .. "/" .. signal.name .. "]"
      textfield.select(#textfield.text + 1, #textfield.text)
      textfield.focus()
    end
    button.elem_value = { type = "virtual", name = "tgps-signal-icon-selector" }
  end,

  --- @param self OverviewGui
  ov_auto_create_groups = function(self)
    groups.auto_create(self.force_index)
    refresh(self)
  end,

  --- @param group_data GroupData
  --- @param e EventData.on_gui_click
  ov_cancel_rename = function(_, group_data, e)
    e.element.parent.visible = false
    e.element.parent.textfield.text = group_data.name
    e.element.parent.parent.standard.visible = true
  end,

  --- @param self OverviewGui
  ov_filter = function(self)
    local text = self.elems.search_textfield.text
    for _, elem in pairs(self.elems.scroll_pane.children) do
      elem.visible = not not string.find(elem.name, text, nil, true)
    end
  end,

  --- @param self OverviewGui
  --- @param group_data GroupData
  ov_edit_schedule = function(self, group_data)
    local _, train_data = next(group_data.trains)
    if not train_data then
      return
    end
    self.player.opened = flib_train.get_main_locomotive(train_data.train)
  end,

  --- @param self OverviewGui
  --- @param group_data GroupData
  --- @param e EventData.on_gui_click
  ov_remove_group = function(self, group_data, e)
    local tags = e.element.tags
    if game.ticks_played - (tags.last_click or 0) > 30 then
      self.player.create_local_flying_text({ text = { "message.tgps-click-again-to-confirm" }, create_at_cursor = true })
      tags.last_click = game.ticks_played
      e.element.tags = tags
      return
    end
    groups.remove_group(self.force_index, group_data.name)
    refresh(self)
  end,

  --- @param self OverviewGui
  --- @param e EventData.on_gui_click
  ov_rename_group = function(self, group_data, e)
    groups.rename_group(self.force_index, group_data.name, e.element.parent.textfield.text)
    refresh(self)
  end,

  --- @param e EventData.on_gui_click
  ov_start_rename = function(_, _, e)
    local rename_flow = e.element.parent.parent.rename
    if not rename_flow then
      return
    end
    e.element.parent.visible = false
    rename_flow.visible = true
    rename_flow.textfield.focus()
    rename_flow.textfield.select_all()
  end,
}

flib_gui.add_handlers(handlers, function(e, handler)
  local self = overview_gui.get(e.player_index)
  if not self then
    return
  end
  local group, group_data = e.element.tags.group, nil
  if group then
    group_data = global.groups[self.force_index][group]
    if not group_data then
      return
    end
  end
  handler(self, group_data, e)
end)

function overview_gui.init()
  --- @type table<uint, OverviewGui>
  global.overview_guis = {}
end

--- @param player LuaPlayer
function overview_gui.build(player)
  overview_gui.destroy(player.index) -- Just in case

  --- @type OverviewGuiElems
  local elems = flib_gui.add(player.gui.relative, {
    type = "frame",
    name = "tgps_overview_window",
    style_mods = { vertically_stretchable = true },
    caption = { "gui.tgps-groups" },
    anchor = {
      gui = defines.relative_gui_type.trains_gui,
      position = defines.relative_gui_position.left,
    },
    {
      type = "frame",
      style = "inside_deep_frame",
      style_mods = { width = 300 },
      direction = "vertical",
      {
        type = "frame",
        style = "subheader_frame",
        {
          type = "textfield",
          name = "search_textfield",
          style = "flib_widthless_textfield",
          style_mods = { horizontally_stretchable = true },
          handler = { [defines.events.on_gui_text_changed] = handlers.ov_filter },
        },
        {
          type = "choose-elem-button",
          name = "icon_selector",
          style = "tool_button",
          style_mods = { padding = 0 },
          tooltip = { "gui.tgps-choose-icon" },
          elem_type = "signal",
          signal = { type = "virtual", name = "tgps-signal-icon-selector" },
          handler = { [defines.events.on_gui_elem_changed] = handlers.ov_add_icon },
        },
      },
      {
        type = "scroll-pane",
        name = "scroll_pane",
        style = "tgps_list_box_scroll_pane",
      },
      {
        type = "flow",
        name = "no_groups_flow",
        style_mods = {
          horizontal_align = "center",
          horizontally_stretchable = true,
          vertical_align = "center",
          vertically_stretchable = true,
          vertical_spacing = 12,
        },
        direction = "vertical",
        { type = "label", caption = { "gui.tgps-no-groups-message" } },
        {
          type = "button",
          caption = { "gui.tgps-auto-create-groups" },
          tooltip = { "gui.tgps-auto-create-groups-tooltip" },
          handler = handlers.ov_auto_create_groups,
        },
      },
    },
  })

  --- @class OverviewGui
  local self = {
    elems = elems,
    force_index = player.force.index,
    player = player,
  }
  global.overview_guis[player.index] = self
  refresh(self)
end

--- @param player_index uint
function overview_gui.destroy(player_index)
  local self = overview_gui.get(player_index)
  if not self then
    return
  end
  local window = self.elems.tgps_overview_window
  if window and window.valid then
    window.destroy()
  end
  global.overview_guis[player_index] = nil
end

--- @param player_index uint
function overview_gui.get(player_index)
  local gui = global.overview_guis[player_index]
  if gui and gui.elems.tgps_overview_window.valid then
    return gui
  end
end

--- @param player_index uint
function overview_gui.set_height(player_index)
  local self = overview_gui.get(player_index)
  if self then
    refresh(self)
  end
end

return overview_gui
