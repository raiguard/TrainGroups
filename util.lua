local flib_gui = require("__flib__/gui-lite")

--- @class TgpsUtil
local util = {}

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
