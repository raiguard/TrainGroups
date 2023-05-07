local util = {}

local debug = false
function util.log(msg)
  if __DebugAdapter or debug then
    log({ "", "[" .. game.tick .. "] ", msg })
  end
end

util.update_train_gui_event = script.generate_event_name()

return util
