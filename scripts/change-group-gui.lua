local flib_gui = require("__flib__/gui-lite")
local flib_train = require("__flib__/train")

local groups = require("__TrainGroups__/scripts/groups")
local util = require("__TrainGroups__/scripts/util")

--- @class ChangeGroupGuiElems
--- @field tgps_change_group_window LuaGuiElement
--- @field tgps_change_group_overlay LuaGuiElement
--- @field textfield LuaGuiElement
--- @field textfield_placeholder LuaGuiElement
--- @field scroll_pane LuaGuiElement

--- @param player_index uint
--- @return boolean
local function destroy_gui(player_index)
  local self = global.change_group_guis[player_index]
  if not self then
    return false
  end
  global.change_group_guis[player_index] = nil

  if not self.player.valid then
    return false
  end

  local window = self.elems.tgps_change_group_window
  if window.valid then
    window.destroy()
  end
  local overlay = self.elems.tgps_change_group_overlay
  if overlay and overlay.valid then
    overlay.destroy()
  end

  if not game.is_multiplayer() and self.player.input_method == defines.input_method.keyboard_and_mouse then
    script.raise_event(util.update_train_gui_event, { player_index = self.player.index })
    return true
  end
  local locomotive = flib_train.get_main_locomotive(self.train)
  if locomotive then
    self.player.opened = locomotive
  end
  return false
end

--- @param self ChangeGroupGui
--- @param group_name string?
local function select_group(self, group_name)
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
  destroy_gui(self.player.index)
end

--- @param self ChangeGroupGui
local function update(self)
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

--- @param self ChangeGroupGui
--- @param e EventData.on_gui_click
local function on_result_click(self, e)
  select_group(self, e.element.name)
end

--- @param self ChangeGroupGui
--- @param e EventData.on_gui_elem_changed
local function add_icon(self, e)
  local button = e.element
  local signal = button.elem_value
  if signal and signal.name ~= "tgps-signal-icon-selector" then
    local textfield = self.elems.textfield
    local type = signal.type == "virtual" and "virtual-signal" or signal.type
    textfield.text = textfield.text .. "[img=" .. type .. "/" .. signal.name .. "]"
    textfield.select(#textfield.text + 1, #textfield.text)
    textfield.focus()
    update(self)
  end
  button.elem_value = { type = "virtual", name = "tgps-signal-icon-selector" }
end

--- @param self ChangeGroupGui
local function on_confirmed(self)
  select_group(self, self.elems.textfield.text)
end

--- @param self ChangeGroupGui
local function on_close_window(self)
  destroy_gui(self.player.index)
end

--- @param player LuaPlayer
--- @param train LuaTrain
local function build_gui(player, train)
  destroy_gui(player.index) -- Just in case

  local resolution = player.display_resolution
  local scale = player.display_scale
  local overlay_size = { resolution.width / scale, resolution.height / scale }

  --- @type ChangeGroupGuiElems
  local elems = flib_gui.add(player.gui.screen, {
    {
      type = "empty-widget",
      name = "tgps_change_group_overlay",
      style_mods = { size = overlay_size },
      handler = { [defines.events.on_gui_click] = on_close_window },
    },
    {
      type = "frame",
      name = "tgps_change_group_window",
      direction = "vertical",
      elem_mods = { auto_center = true },
      handler = { [defines.events.on_gui_closed] = on_close_window },
      {
        type = "flow",
        style = "flib_titlebar_flow",
        drag_target = "tgps_change_group_window",
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
          handler = on_close_window,
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
            style = "flib_widthless_textfield",
            style_mods = { horizontally_stretchable = true },
            handler = {
              [defines.events.on_gui_confirmed] = on_confirmed,
              [defines.events.on_gui_text_changed] = update,
            },
            {
              type = "label",
              name = "textfield_placeholder",
              style_mods = { font_color = { 0, 0, 0, 0.4 } },
              caption = { "gui.tgps-no-group-assigned" },
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
            handler = { [defines.events.on_gui_elem_changed] = add_icon },
          },
          {
            type = "sprite-button",
            style = "flib_tool_button_light_green",
            sprite = "utility/enter",
            tooltip = { "gui.confirm" },
            handler = on_confirmed,
          },
        },
        {
          type = "scroll-pane",
          name = "scroll_pane",
          style = "tgps_list_box_scroll_pane",
          style_mods = { maximal_height = 28 * 16 },
        },
      },
    },
  })

  -- Populate list box
  --- @type GuiElemDef[]
  local items = {
    {
      type = "button",
      style = "tgps_list_box_item",
      caption = { "gui.tgps-no-group-assigned" },
      handler = on_result_click,
    },
  }
  for name, group_data in pairs(global.groups[player.force.index]) do
    table.insert(items, {
      type = "button",
      name = name,
      style = "tgps_list_box_item",
      caption = { "gui.tgps-name-and-count", name, table_size(group_data.trains) },
      handler = on_result_click,
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
    train_id = train.id,
    train = train,
  }

  if game.is_multiplayer() or self.player.input_method == defines.input_method.game_controller then
    player.opened = self.elems.tgps_change_group_window
  end

  global.change_group_guis[player.index] = self
  update(self)
end

--- @param player LuaPlayer
--- @param train LuaTrain
local function open_gui(player, train)
  local self = global.change_group_guis[player.index]
  if self then
    update(self)
  else
    build_gui(player, train)
  end
end

--- @param e EventData.on_gui_closed
local function on_gui_closed(e)
  if e.gui_type == defines.gui_type.entity and destroy_gui(e.player_index) then
    game.get_player(e.player_index).opened = e.entity
  end
end

--- @param e EventData.on_train_created
local function on_train_created(e)
  if not global.change_group_guis then
    return
  end
  if not e.old_train_id_1 and not e.old_train_id_2 then
    return
  end
  for _, self in pairs(global.change_group_guis) do
    if self.train.valid then
      goto continue
    end
    if self.train_id == e.old_train_id_1 or self.train_id == e.old_train_id_2 then
      self.train = e.train
      self.train_id = e.train.id
      update(self)
    end
    ::continue::
  end
end

--- @param e on_se_train_teleported
local function on_se_elevator_teleport_started(e)
  -- XXX: on_gui_closed isn't raised when a train starts going through an elevator
  for _, gui_data in pairs(global.change_group_guis) do
    local train = gui_data.train
    if train.valid and train.id == e.old_train_id_1 then
      destroy_gui(gui_data.player.index)
    end
  end
end

local change_group_gui = {}

function change_group_gui.on_init()
  --- @type table<uint, ChangeGroupGui>
  global.change_group_guis = {}
end

change_group_gui.events = {
  [defines.events.on_gui_closed] = on_gui_closed,
  [defines.events.on_train_created] = on_train_created,
}

function change_group_gui.add_remote_interface()
  if
    not script.active_mods["space-exploration"]
    or not remote.interfaces["space-exploration"]["get_on_train_teleport_started_event"]
  then
    return
  end
  local started_event = remote.call("space-exploration", "get_on_train_teleport_started_event")
  change_group_gui.events[started_event] = on_se_elevator_teleport_started
end

flib_gui.add_handlers({
  cg_add_icon = add_icon,
  cg_on_close_window = on_close_window,
  cg_on_confirmed = on_confirmed,
  cg_on_result_click = on_result_click,
  cg_update = update,
}, function(e, handler)
  local self = global.change_group_guis[e.player_index]
  if not self and self.train.valid then
    return
  end
  if not self.train.valid then
    if self.player.opened_gui_type ~= defines.gui_type.entity then
      return
    end
    local opened = self.player.opened
    if not opened or opened.type ~= "locomotive" then
      return
    end
    local train = opened.train
    if not train or not train.valid then
      return
    end
    self.train = train --[[@as LuaTrain]]
  end

  handler(self, e)
end)

change_group_gui.open = open_gui

return change_group_gui
