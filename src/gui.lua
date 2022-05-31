local gui_util = require("__flib__.gui")
local train_util = require("__flib__.train")
local table = require("__flib__.table")

local groups = require("groups")

--- @param train LuaTrain
--- @return LocalisedString[] items
--- @return number selected_index
local function get_dropdown_items(train)
  local locomotive = train_util.get_main_locomotive(train)
  if not locomotive then
    error("Opened train has no locomotives - this should be impossible!")
  end

  -- Gather and sort group names
  local group_names = {}
  local group_members = {}
  for name, data in pairs(global.groups[locomotive.force.index]) do
    table.insert(group_names, name)
    group_members[name] = #data.trains
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

  return dropdown_items, selected
end

local gui = {}

function gui.init()
  global.guis = {}
end

--- @param player LuaPlayer
--- @param train LuaTrain
function gui.build(player, train)
  -- Just in case
  if player.gui.relative["tgps-window"] then
    gui.destroy(player)
  end

  local dropdown_items, selected = get_dropdown_items(train)

  gui_util.build(player.gui.relative, {
    {
      type = "frame",
      name = "tgps-window",
      style = "quick_bar_window_frame",
      -- Relative GUI will stretch top frames by default for some reason
      style_mods = {
        horizontally_stretchable = false,
      },
      anchor = { gui = defines.relative_gui_type.train_gui, position = defines.relative_gui_position.top },
      {
        type = "frame",
        style = "inside_deep_frame",
        {
          type = "drop-down",
          name = "dropdown",
          items = dropdown_items,
          selected_index = selected,
          actions = {
            on_selection_state_changed = "handle_dropdown_selection",
          },
        },
        {
          type = "sprite-button",
          name = "rename_button",
          style = "tool_button",
          sprite = "utility/rename_icon_normal",
          tooltip = { "gui.tgps-rename-group" },
          visible = selected > 1,
          actions = {
            on_click = "toggle_rename_group",
          },
        },
        {
          type = "textfield",
          name = "textfield",
          visible = false,
          actions = {
            on_confirmed = "handle_confirmed",
            on_text_changed = "update_textfield_style",
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
          actions = {
            on_elem_changed = "add_icon",
          },
        },
        {
          type = "sprite-button",
          name = "confirm_button",
          style = "item_and_count_select_confirm",
          style_mods = { top_margin = 0 },
          sprite = "utility/check_mark",
          visible = false,
          actions = {
            on_click = "handle_confirmed",
          },
        },
      },
    },
  })
end

--- @param player LuaPlayer
function gui.destroy(player)
  local window = player.gui.relative["tgps-window"]
  if window and window.valid then
    window.destroy()
  end
end

-- EVENT HANDLERS

--- @param elem LuaGuiElement
--- @param train LuaTrain
function gui.handle_dropdown_selection(elem, train)
  -- Show or hide group creation
  if elem.selected_index == #elem.items then
    elem.parent.rename_button.visible = false --- @diagnostic disable-line
    elem.parent.textfield.visible = true --- @diagnostic disable-line
    elem.parent.textfield.text = "" --- @diagnostic disable-line
    elem.parent.textfield.focus() --- @diagnostic disable-line
    gui.update_textfield_style(elem.parent.textfield) --- @diagnostic disable-line
    elem.parent.icon_selector.visible = true --- @diagnostic disable-line
    elem.parent.confirm_button.visible = true --- @diagnostic disable-line
    return
  else
    elem.parent.rename_button.visible = true --- @diagnostic disable-line
    elem.parent.rename_button.style = "tool_button" --- @diagnostic disable-line
    elem.parent.textfield.visible = false --- @diagnostic disable-line
    elem.parent.icon_selector.visible = false --- @diagnostic disable-line
    elem.parent.confirm_button.visible = false --- @diagnostic disable-line
    elem.parent.focus()
  end

  if elem.selected_index == 1 then
    elem.parent.rename_button.visible = false --- @diagnostic disable-line
  end

  -- Change group
  local group_name = elem.items[elem.selected_index][2]
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

  gui.refresh_dropdown(elem.parent.dropdown, train) --- @diagnostic disable-line
end

--- @param elem LuaGuiElement
--- @param train LuaTrain
function gui.handle_confirmed(elem, train)
  local group_name = elem.parent.textfield.text --- @diagnostic disable-line
  if #group_name == 0 then
    return
  end

  local force_index = train.carriages[1].force.index

  -- Don't allow overwriting an existing group
  if global.groups[force_index][group_name] then
    local player = game.get_player(elem.player_index)
    player.create_local_flying_text({
      text = { "gui.tgps-group-exists", group_name },
      create_at_cursor = true,
    })
    player.play_sound({ path = "utility/cannot_build" })
    return
  end

  local train_data = global.trains[train.id]
  if train_data then
    local rename_button = elem.parent.rename_button --- @diagnostic disable-line
    local is_renaming = rename_button.visible and rename_button.style.name == "flib_selected_tool_button" --- @diagnostic disable-line
    if is_renaming then
      groups.rename_group(force_index, train_data.group, group_name)
    else
      groups.change_train_group(train_data, group_name)
    end
  else
    groups.add_train(train, group_name)
  end

  elem.parent.rename_button.visible = true --- @diagnostic disable-line
  elem.parent.rename_button.style = "tool_button" --- @diagnostic disable-line
  elem.parent.textfield.visible = false --- @diagnostic disable-line
  elem.parent.icon_selector.visible = false --- @diagnostic disable-line
  elem.parent.confirm_button.visible = false --- @diagnostic disable-line

  gui.refresh_dropdown(elem.parent.dropdown, train) --- @diagnostic disable-line
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
  --- @type SignalID
  local value = selector.elem_value
  local type = value.type
  if type == "virtual" then
    type = "virtual-signal"
  end
  --- @type LuaGuiElement
  local textfield = selector.parent.textfield --- @diagnostic disable-line
  -- We can't read the cursor position, so just stick it at the end
  textfield.text = textfield.text .. "[" .. type .. "=" .. value.name .. "]"

  -- Always show the icon selector
  selector.elem_value = { type = "virtual", name = "tgps-signal-icon-selector" }

  gui.update_textfield_style(textfield)
  textfield.focus()
  textfield.select(#textfield.text, #textfield.text)
end

--- @param rename_button LuaGuiElement
function gui.toggle_rename_group(rename_button, train)
  local train_data = global.trains[train.id]
  if rename_button.style.name == "flib_selected_tool_button" then
    rename_button.style = "tool_button"
    rename_button.parent.textfield.visible = false --- @diagnostic disable-line
    rename_button.parent.icon_selector.visible = false --- @diagnostic disable-line
    rename_button.parent.confirm_button.visible = false --- @diagnostic disable-line
  elseif train_data then
    rename_button.style = "flib_selected_tool_button"
    rename_button.parent.textfield.text = train_data.group --- @diagnostic disable-line
    rename_button.parent.textfield.visible = true --- @diagnostic disable-line
    rename_button.parent.textfield.select_all() --- @diagnostic disable-line
    rename_button.parent.textfield.focus() --- @diagnostic disable-line
    rename_button.parent.icon_selector.visible = true --- @diagnostic disable-line
    rename_button.parent.confirm_button.visible = true --- @diagnostic disable-line
  end
end

return gui
