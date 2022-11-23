data:extend({
  {
    type = "virtual-signal",
    name = "tgps-signal-icon-selector",
    icon = "__core__/graphics/icons/mip/select-icon-black.png",
    icon_size = 40,
    icon_mipmaps = 2,
    subgroup = "virtual-signal",
    order = "z",
  },
})

local styles = data.raw["gui-style"]["default"]

styles.tgps_relative_group_button = {
  type = "button_style",
  parent = "list_box_item",
  height = 36,
  font = "default-bold",
  default_font_color = bold_font_color,
}

styles.tgps_list_box_scroll_pane = {
  type = "scroll_pane_style",
  parent = "list_box_scroll_pane",
  vertical_flow_style = {
    type = "vertical_flow_style",
    vertical_spacing = 0,
  },
}

styles.tgps_list_box_item = {
  type = "button_style",
  parent = "list_box_item",
  horizontally_stretchable = "on",
}
