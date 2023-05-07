local migration = require("__flib__/migration")

local change_group_gui = require("__TrainGroups__/scripts/change-group-gui")
local overview_gui = require("__TrainGroups__/scripts/overview-gui")
local train_gui = require("__TrainGroups__/scripts/train-gui")

local function on_configuration_changed(e)
  migration.on_config_changed(e, {
    ["1.0.4"] = function()
      global.to_delete = {}
    end,
    ["1.1.3"] = function()
      -- Convert train lists to a hashmap
      for _, force_groups in pairs(global.groups) do
        for _, group in pairs(force_groups) do
          local new = {}
          for _, train_id in pairs(group.trains) do
            local train_data = global.trains[train_id]
            if train_data then
              new[train_id] = train_data
            end
          end
          group.trains = new
        end
      end
    end,
    ["1.1.5"] = function()
      local new_groups = {}
      for force_index, force_groups in pairs(global.groups) do
        new_groups[force_index] = {}
        for name, group in pairs(force_groups) do
          local new_trains = {}
          -- Verify that each train belongs to this group
          for train_id, train_data in pairs(group.trains) do
            if train_data.group == name then
              new_trains[train_id] = train_data
            end
          end
          group.trains = new_trains
          -- Cull any groups that have no trains
          if table_size(new_trains) > 0 then
            new_groups[force_index][name] = group
          end
        end
      end
      global.groups = new_groups
    end,
    ["1.1.6"] = function()
      -- updating_schedule was changed to ignore_schedule
      for _, train_data in pairs(global.trains) do
        train_data.ignore_schedule = false
        train_data.updating_schedule = nil
      end
    end,
    ["1.2.0"] = function()
      -- Destroy old GUIs (name was changed)
      for _, player in pairs(game.players) do
        local window = player.gui.relative["tgps-window"]
        if window and window.valid then
          window.destroy()
        end
      end
      -- Init new GUIs
      change_group_gui.on_init()
      overview_gui.on_init()
      train_gui.on_init()
    end,
    ["1.3.2"] = function()
      -- Ensure that all trains can sync schedules
      for _, train_data in pairs(global.trains) do
        train_data.ignore_schedule = false
      end
    end,
  })
end

local migrations = {}

migrations.on_configuration_changed = on_configuration_changed

return migrations
