local gui = require("__flib__/gui-lite")
local migration = require("__flib__/migration")
local table = require("__flib__/table")

local change_group_gui = require("__TrainGroups__/change-group-gui")
local groups = require("__TrainGroups__/groups")
local overview_gui = require("__TrainGroups__/overview-gui")
local train_gui = require("__TrainGroups__/train-gui")

DEBUG = false
function LOG(msg)
  if __DebugAdapter or DEBUG then
    log({ "", "[" .. game.tick .. "] ", msg })
  end
end

--- @class on_train_teleported
--- @field train LuaTrain
--- @field old_train_id_1 uint?
--- @field old_surface_index uint
--- @field teleporter LuaEntity

local function on_se_elevator()
  if
    script.active_mods["space-exploration"]
    and remote.interfaces["space-exploration"]["get_on_train_teleport_started_event"]
  then
    script.on_event(
      remote.call("space-exploration", "get_on_train_teleport_started_event"),
      --- @param e on_train_teleported
      function(e)
        LOG("ON_TRAIN_TELEPORT_STARTED: [" .. e.old_train_id_1 .. "] -> [" .. e.train.id .. "]")
        local old_train_data = global.trains[e.old_train_id_1]
        if old_train_data then
          old_train_data.ignore_schedule = true
          groups.migrate_trains(e.train, e.old_train_id_1)
        end
        -- XXX: on_gui_closed isn't raised when a train starts going through an elevator
        for _, gui_data in pairs(global.change_group_guis) do
          local train = gui_data.train
          if train.valid and train.id == e.old_train_id_1 then
            change_group_gui.destroy(gui_data.player.index)
          end
        end
      end
    )
    script.on_event(
      remote.call("space-exploration", "get_on_train_teleport_finished_event"),
      --- @param e on_train_teleported
      function(e)
        LOG("ON_TRAIN_TELEPORT_FINISHED: [" .. (e.old_train_id_1 or "") .. "] -> [" .. e.train.id .. "]")
        local train_data = global.trains[e.train.id]
        if train_data then
          train_data.ignore_schedule = false
        end
      end
    )
  end
end

local rolling_stock_filter = { { filter = "rolling-stock" } }

local rolling_stock_types = {
  ["locomotive"] = true,
  ["cargo-wagon"] = true,
  ["fluid-wagon"] = true,
  ["artillery-wagon"] = true,
}

script.on_init(function()
  on_se_elevator()

  groups.init()
  change_group_gui.init()
  overview_gui.init()
  train_gui.init()

  for _, force in pairs(game.forces) do
    groups.init_force(force)
  end
end)

script.on_load(function()
  on_se_elevator()
end)

migration.handle_on_configuration_changed({
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
    change_group_gui.init()
    overview_gui.init()
    train_gui.init()
  end,
  ["1.3.2"] = function()
    -- Ensure that all trains can sync schedules
    for _, train_data in pairs(global.trains) do
      train_data.ignore_schedule = false
    end
  end,
})

script.on_event(defines.events.on_force_created, function(e)
  groups.init_force(e.force)
end)

script.on_event(defines.events.on_gui_opened, function(e)
  if e.gui_type == defines.gui_type.entity then
    local entity = e.entity
    if entity and entity.valid and entity.type == "locomotive" then
      local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
      train_gui.build(player, entity.train)
    end
  elseif e.gui_type == defines.gui_type.trains then
    local player = game.get_player(e.player_index) --[[@as LuaPlayer]]
    overview_gui.build(player)
  end
end)

gui.handle_events()

script.on_event(defines.events.on_gui_closed, function(e)
  if e.gui_type == defines.gui_type.entity then
    train_gui.destroy(e.player_index)
    if change_group_gui.destroy(e.player_index) then
      game.get_player(e.player_index).opened = e.entity
    end
  elseif e.gui_type == defines.gui_type.trains then
    overview_gui.destroy(e.player_index)
  end
end)

script.on_event(defines.events.on_player_setup_blueprint, function(e)
  local player = game.get_player(e.player_index) --[[@as LuaPlayer]]

  -- Get blueprint
  local bp = player.blueprint_to_setup
  if not bp or not bp.valid_for_read then
    bp = player.cursor_stack
    if not bp then
      return
    end
    if bp.type == "blueprint-book" then
      local item_inventory = bp.get_inventory(defines.inventory.item_main)
      if item_inventory then
        bp = item_inventory[bp.active_index]
      else
        return
      end
    end
  end

  local entities = bp.get_blueprint_entities()
  if not entities or #entities == 0 then
    return
  end

  local set = false
  for _, bp_entity in pairs(entities) do
    local prototype = game.entity_prototypes[bp_entity.name]
    if prototype and rolling_stock_types[prototype.type] then
      local entity = e.surface.find_entities_filtered({ name = bp_entity.name, position = bp_entity.position })[1]
      if entity then
        local train = entity.train
        if train and train.valid then
          local train_data = global.trains[train.id]
          if train_data then
            set = true
            bp_entity.tags = bp_entity.tags or {}
            bp_entity.tags.train_group = train_data.group
          end
        end
      end
    end
  end

  if set then
    bp.set_blueprint_entities(entities)
  end
end)

script.on_event(
  { defines.events.on_player_display_resolution_changed, defines.events.on_player_display_scale_changed },
  function(e)
    overview_gui.set_height(e.player_index)
  end
)

--- @param e EventData.on_built_entity|EventData.on_robot_built_entity|EventData.script_raised_built|EventData.script_raised_revive
local function on_built(e)
  local tags = e.tags
  if not tags or not tags.train_group then
    return
  end

  local entity = e.created_entity or e.entity
  if not entity or not entity.valid then
    return
  end

  groups.add_train(entity.train, tags.train_group --[[@as string?]])
end
script.on_event(defines.events.on_built_entity, on_built, rolling_stock_filter)
script.on_event(defines.events.on_robot_built_entity, on_built, rolling_stock_filter)
script.on_event(defines.events.script_raised_built, on_built, rolling_stock_filter)
script.on_event(defines.events.script_raised_revive, on_built, rolling_stock_filter)

script.on_event(defines.events.on_entity_cloned, function(e)
  local source = e.source
  local destination = e.destination

  local source_train = source.train
  local destination_train = destination.train
  if not source_train or not destination_train then
    return
  end

  local source_train_data = global.trains[source_train.id]
  if not source_train_data then
    return
  end
  if global.trains[destination_train.id] then
    return
  end

  groups.add_train(destination_train, source_train_data.group)
end, rolling_stock_filter)

script.on_event(defines.events.on_pre_entity_settings_pasted, function(e)
  if e.source.type == "locomotive" and e.destination.type == "locomotive" then
    local destination_train = e.destination.train --[[@as LuaTrain]]
    local destination_train_data = global.trains[destination_train.id]
    if destination_train_data then
      -- Add a flag to ignore the schedule change for the destination train
      destination_train_data.ignore_schedule = true
    end
  end
end)

script.on_event(defines.events.on_entity_settings_pasted, function(e)
  local source = e.source
  local destination = e.destination

  if source.type == "locomotive" and destination.type == "locomotive" then
    LOG("SETTINGS PASTED")
    local source_train = source.train --[[@as LuaTrain]]
    local destination_train = destination.train --[[@as LuaTrain]]
    local source_train_data = global.trains[source_train.id]
    local destination_train_data = global.trains[destination_train.id]

    if not source_train_data and destination_train_data then
      groups.remove_train(destination_train_data)
    elseif source_train_data and not destination_train_data then
      groups.add_train(destination_train, source_train_data.group)
    elseif source_train_data and destination_train_data then
      groups.change_train_group(destination_train_data, source_train_data.group)
      destination_train_data.ignore_schedule = false
    end
  end
end)

--- @param e EventData.on_player_mined_entity|EventData.on_robot_mined_entity|EventData.on_entity_died|EventData.script_raised_destroy
local function on_destroyed(e)
  local train = e.entity.train --[[@as LuaTrain]]
  LOG(string.upper(table.find(defines.events, e.name)) .. ": [" .. train.id .. "]")
  local train_data = global.trains[train.id]
  if not train_data then
    return
  end
  -- If this is the last rolling stock in the train
  if #train.carriages == 1 then
    groups.remove_train(train_data)
  end
end
script.on_event(defines.events.on_player_mined_entity, on_destroyed, rolling_stock_filter)
script.on_event(defines.events.on_robot_mined_entity, on_destroyed, rolling_stock_filter)
script.on_event(defines.events.on_entity_died, on_destroyed, rolling_stock_filter)
script.on_event(defines.events.script_raised_destroy, on_destroyed, rolling_stock_filter)

script.on_event(defines.events.on_train_created, function(e)
  if e.old_train_id_1 or e.old_train_id_2 then
    groups.migrate_trains(e.train, e.old_train_id_1, e.old_train_id_2)
  end
end)

script.on_event(defines.events.on_train_schedule_changed, function(e)
  LOG("ON_TRAIN_SCHEDULE_CHANGED: [" .. e.train.id .. "]")
  -- Only update if a player intentionally changed something
  if e.player_index then
    groups.update_group_schedule(e.train)
  end
end)

script.on_event(defines.events.on_entity_renamed, function(e)
  local entity = e.entity
  if entity.type ~= "train-stop" then
    return
  end
  local force_groups = global.groups[entity.force.index]
  if not force_groups then
    return
  end
  local force = entity.force
  if #game.get_train_stops({ force = force, name = e.old_name }) == 0 then
    groups.rename_station(force_groups, e.old_name, entity.backer_name)
  end
end)

script.on_event(defines.events.on_tick, function()
  for train_id in pairs(global.to_delete) do
    local train_data = global.trains[train_id]
    if train_data then
      groups.remove_train(train_data)
    end
  end
  global.to_delete = {}
end)
