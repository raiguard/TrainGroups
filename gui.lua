local gui_util = require("__flib__/gui-lite")
local train_util = require("__flib__/train")
local table = require("__flib__/table")

local groups = require("__TrainGroups__/groups")

--- @param train LuaTrain
--- @return LocalisedString[] items
--- @return uint selected_index
local function get_dropdown_items(train)
  local locomotive = train_util.get_main_locomotive(train)
  if not locomotive then
    error("Opened train has no locomotives - this should be impossible!")
  end

  -- Gather and sort group names
  local group_names = {}
  local group_members = {}
  for name, group in pairs(global.groups[locomotive.force.index]) do
    table.insert(group_names, name)
    group_members[name] = table_size(group.trains)
  end
  table.sort(group_names)

  -- Assemble dropdown items
  local dropdown_items = { { "gui.tgps-no-group" } }
  local selected = 1
  -- If the train data doesn't exist then it will naturally select the "no group" item
  local train_data = global.trains[train.id] or {}
  if train_data then
    for i, name in pairs(group_names) do
      table.insert(dropdown_items, { "gui.tgps-name-and-members", name, group_members[name] })
      if name == train_data.group then
        selected = i + 1
      end
    end
  end
  table.insert(dropdown_items, { "gui.tgps-create-group" })

  return dropdown_items, selected --[[@as uint]]
end

local gui = {}

--- @param player LuaPlayer
--- @param train LuaTrain
function gui.build(player, train)
  -- Just in case
  gui.destroy(player)

  local dropdown_items, selected = get_dropdown_items(train)

  gui_util.add(player.gui.relative, {
    {
      type = "frame",
      name = "tgps_window",
      style = "quick_bar_window_frame",
      -- Relative GUI will stretch top frames by default for some reason
      style_mods = { horizontally_stretchable = false },
      anchor = { gui = defines.relative_gui_type.train_gui, position = defines.relative_gui_position.top },
      {
        type = "frame",
        style = "inside_deep_frame",
        {
          type = "drop-down",
          name = "dropdown",
          items = dropdown_items,
          selected_index = selected,
          handler = {
            [defines.events.on_gui_selection_state_changed] = gui.on_dropdown_selection,
          },
        },
        {
          type = "sprite-button",
          name = "rename_button",
          style = "tool_button",
          sprite = "utility/rename_icon_normal",
          tooltip = { "gui.tgps-rename-group" },
          visible = selected > 1,
          handler = {
            [defines.events.on_gui_click] = gui.toggle_rename_group,
          },
        },
        {
          type = "textfield",
          name = "textfield",
          visible = false,
          handler = {
            [defines.events.on_gui_confirmed] = gui.on_confirmed,
            [defines.events.on_gui_text_changed] = gui.update_textfield_style,
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
          visible = false,
          handler = {
            [defines.events.on_gui_elem_changed] = gui.add_icon,
          },
        },
        {
          type = "sprite-button",
          name = "confirm_button",
          style = "item_and_count_select_confirm",
          style_mods = { top_margin = 0 },
          sprite = "utility/check_mark",
          visible = false,
          handler = {
            [defines.events.on_gui_click] = gui.on_confirmed,
          },
        },
      },
    },
  })
end

--- @param player LuaPlayer
function gui.destroy(player)
  local window = player.gui.relative.tgps_window
  if window and window.valid then
    window.destroy()
  end
end

--- @param elem LuaGuiElement
--- @param train LuaTrain
function gui.on_dropdown_selection(elem, train)
  -- Show or hide group creation
  if elem.selected_index == #elem.items then
    elem.parent.rename_button.visible = false
    elem.parent.textfield.visible = true
    elem.parent.textfield.text = ""
    elem.parent.textfield.focus()
    gui.update_textfield_style(elem.parent.textfield)
    elem.parent.icon_selector.visible = true
    elem.parent.confirm_button.visible = true
    return
  else
    elem.parent.rename_button.visible = true
    elem.parent.rename_button.style = "tool_button"
    elem.parent.textfield.visible = false
    elem.parent.icon_selector.visible = false
    elem.parent.confirm_button.visible = false
    elem.parent.focus()
  end

  if elem.selected_index == 1 then
    elem.parent.rename_button.visible = false
  end

  -- Change group
  local group_name = elem.items[elem.selected_index][2] --[[@as string]]
  local train_data = global.trains[train.id]
  if train_data then
    if elem.selected_index > 1 then
      groups.change_train_group(train_data, group_name)
    else
      groups.remove_train(train_data)
    end
  elseif elem.selected_index > 1 then
    groups.add_train(train, group_name)
  end

  gui.refresh_dropdown(elem.parent.dropdown, train)
end

--- @param elem LuaGuiElement
--- @param train LuaTrain
function gui.on_confirmed(elem, train)
  local group_name = elem.parent.textfield.text --[[@as string]]
  if #group_name == 0 then
    return
  end

  local force_index = train.carriages[1].force.index

  -- Don't allow overwriting an existing group
  if global.groups[force_index][group_name] then
    local player = game.get_player(elem.player_index --[[@as uint]]) --[[@as LuaPlayer]]
    player.create_local_flying_text({
      text = { "gui.tgps-group-exists", group_name },
      create_at_cursor = true,
    })
    player.play_sound({ path = "utility/cannot_build" })
    return
  end

  local train_data = global.trains[train.id]
  if train_data then
    local rename_button = elem.parent.rename_button --[[@as LuaGuiElement]]
    local is_renaming = rename_button.visible and rename_button.style.name == "flib_selected_tool_button"
    if is_renaming then
      groups.rename_group(force_index, train_data.group, group_name)
    else
      groups.change_train_group(train_data, group_name)
    end
  else
    groups.add_train(train, group_name)
  end

  elem.parent.rename_button.visible = true
  elem.parent.rename_button.style = "tool_button"
  elem.parent.textfield.visible = false
  elem.parent.icon_selector.visible = false
  elem.parent.confirm_button.visible = false

  gui.refresh_dropdown(elem.parent.dropdown, train)
end

--- @param dropdown LuaGuiElement
--- @param train LuaTrain
function gui.refresh_dropdown(dropdown, train)
  local items, selected_index = get_dropdown_items(train)
  dropdown.items = items
  dropdown.selected_index = selected_index
end

--- @param textfield LuaGuiElement
function gui.update_textfield_style(textfield, _)
  if #textfield.text > 0 then
    textfield.style = "textbox"
  else
    textfield.style = "invalid_value_textfield"
  end
end

--- @param selector LuaGuiElement
function gui.add_icon(selector, _)
  local value = selector.elem_value
  if not value then
    return
  end
  local type = value.type
  if type == "virtual" then
    type = "virtual-signal"
  end
  local textfield = selector.parent.textfield --[[@as LuaGuiElement]]
  -- We can't read the cursor position, so just stick it at the end
  textfield.text = textfield.text .. "[" .. type .. "=" .. value.name .. "]"

  -- Always show the icon selector
  selector.elem_value = { type = "virtual", name = "tgps-signal-icon-selector" }

  gui.update_textfield_style(textfield)
  textfield.focus()
  textfield.select(#textfield.text + 1, #textfield.text)
end

--- @param rename_button LuaGuiElement
function gui.toggle_rename_group(rename_button, train)
  local train_data = global.trains[train.id]
  if rename_button.style.name == "flib_selected_tool_button" then
    rename_button.style = "tool_button"
    rename_button.parent.textfield.visible = false
    rename_button.parent.icon_selector.visible = false
    rename_button.parent.confirm_button.visible = false
  elseif train_data then
    rename_button.style = "flib_selected_tool_button"
    rename_button.parent.textfield.text = train_data.group
    rename_button.parent.textfield.visible = true
    rename_button.parent.textfield.select_all()
    rename_button.parent.textfield.focus()
    rename_button.parent.icon_selector.visible = true
    rename_button.parent.confirm_button.visible = true
  end
end

gui_util.add_handlers(gui, function(e, handler)
  local elem = e.element
  local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
  local opened = player.opened

  if player.opened_gui_type == defines.gui_type.entity and opened and opened.type == "locomotive" then
    handler(elem, opened.train --[[@as LuaTrain]])
  end
end)

gui.handle_events = gui_util.handle_events

return gui
