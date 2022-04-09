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
  for name in pairs(global.groups[locomotive.force.index]) do
    table.insert(group_names, name)
  end
  table.sort(group_names)

  -- Assemble dropdown items
  local dropdown_items = { { "gui.tgps-no-group" } }
  local selected = 1
  -- If the train data doesn't exist then it will naturally select the "no group" item
  local train_data = global.trains[train.id] or {}
  if train_data then
    for i, name in pairs(group_names) do
      table.insert(dropdown_items, name)
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
          type = "textfield",
          name = "textfield",
          visible = false,
          actions = {
            on_confirmed = "create_group",
            on_text_changed = "update_textfield_style",
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
            on_click = "create_group",
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
    elem.parent.textfield.visible = true --- @diagnostic disable-line
    elem.parent.textfield.text = "" --- @diagnostic disable-line
    elem.parent.textfield.focus() --- @diagnostic disable-line
    gui.update_textfield_style(elem.parent.textfield) --- @diagnostic disable-line
    elem.parent.confirm_button.visible = true --- @diagnostic disable-line
    return
  else
    elem.parent.textfield.visible = false --- @diagnostic disable-line
    elem.parent.confirm_button.visible = false --- @diagnostic disable-line
    elem.parent.focus()
  end

  -- Change group
  local group_name = elem.items[elem.selected_index]
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
function gui.create_group(elem, train)
  local group_name = elem.parent.textfield.text --- @diagnostic disable-line
  if #group_name == 0 then
    return
  end

  local train_data = global.trains[train.id]
  if train_data then
    groups.change_train_group(train_data, group_name)
  else
    groups.add_train(train, group_name)
  end

  elem.parent.confirm_button.visible = false --- @diagnostic disable-line
  elem.parent.textfield.visible = false --- @diagnostic disable-line

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

return gui
