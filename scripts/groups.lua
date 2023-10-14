local table = require("__flib__/table")

local util = require("__TrainGroups__/scripts/util")

--- @class GroupData
--- @field name string
--- @field schedule TrainScheduleRecord[]?
--- @field trains table<uint, TrainData>

--- @class TrainData
--- @field force uint
--- @field group string
--- @field id uint
--- @field train LuaTrain
--- @field ignore_schedule boolean

local tss_signal_names = {
  "[virtual-signal=train-schedule-output-signal]",
  "[virtual-signal=train-schedule-input-signal]",
  "[virtual-signal=refuel-signal]", -- This is actually from TCS, but TSS uses it if present
}
local tcs_present = script.active_mods["Train_Control_Signals"]
local tss_present = script.active_mods["TrainScheduleSignals"]
--- Remove temporary stations, remove Train Control Signals skip signal, and remove wait conditions if
--- they are being managed by Train Schedule Signals
--- @param records TrainScheduleRecord[]
--- @return TrainScheduleRecord[]
local function sanitize_records(records)
  local new = {}
  for _, record in pairs(records) do
    local station_name = record.station
    if station_name then
      -- Remove TCS skip signal if present
      if tcs_present then
        station_name = string.gsub(record.station, "%[virtual%-signal=skip%-signal%]", "")
        record.station = station_name
      end
      -- Remove wait conditions if TSS is being used
      if tss_present then
        for _, signal in pairs(tss_signal_names) do
          if string.find(station_name, signal, 1, true) then
            record.wait_conditions = nil
            break
          end
        end
      end
      table.insert(new, record)
    end
  end
  return new
end

--- @param records TrainScheduleRecord[]
--- @return string
local function get_schedule_string(records)
  local out = {}
  for _, record in pairs(sanitize_records(records)) do
    table.insert(out, record.station)
  end
  return table.concat(out, " → ")
end

--- @param force LuaForce
local function init_force(force)
  --- @type table<string, GroupData>
  global.groups[force.index] = {}
end

--- @param train_data TrainData
--- @param new_group? string
local function change_train_group(train_data, new_group)
  -- Remove from old group
  local old_group = train_data.group
  util.log(
    "CHANGE TRAIN GROUP: [" .. train_data.id .. "] | [" .. (old_group or "") .. "] -> [" .. (new_group or "") .. "]"
  )
  if old_group then
    local group_data = global.groups[train_data.force][old_group]
    -- While this is never supposed to be nil, someone did get a crash with it
    -- Unfortunately it was a private email
    if group_data then
      local group_trains = group_data.trains
      group_trains[train_data.id] = nil
      if table_size(group_data.trains) == 0 then
        global.groups[train_data.force][old_group] = nil
      end
    end
  end
  if new_group then
    -- Add to new group
    train_data.group = new_group
    local group_data = global.groups[train_data.force][new_group]
    if not group_data then
      -- Create group data if it doesn't exist
      group_data = {
        name = new_group,
        -- Use the schedule for the current train as the base
        schedule = train_data.train.schedule and sanitize_records(train_data.train.schedule.records),
        trains = {},
      }
      global.groups[train_data.force][new_group] = group_data
    end
    local group_trains = group_data.trains
    group_trains[train_data.id] = train_data

    local train = train_data.train
    if not train_data.ignore_schedule and group_data.schedule and #group_data.schedule > 0 then
      -- Set to the first station of the same name in the group, if any
      local active_index = 1
      local current_schedule = train.schedule
      if current_schedule then
        local current_record = sanitize_records(current_schedule.records)[current_schedule.current]
        if current_record then
          for i, record in pairs(group_data.schedule) do
            if record.station and record.station == current_record.station then
              active_index = i
              break
            end
          end
        end
      end
      train.schedule = {
        current = active_index,
        records = group_data.schedule,
      }
    end
  end
end

--- @param train LuaTrain
--- @param group string
--- @param ignore_schedule boolean?
--- @return TrainData?
local function add_train(train, group, ignore_schedule)
  local train_id = train.id
  if global.trains[train_id] then
    util.log("NOT ADDING TRAIN, DUPLICATE: [" .. train_id .. "]")
    return
  end
  util.log("ADD TRAIN: [" .. train.id .. "]")

  --- @type TrainData
  local train_data = {
    force = train.carriages[1].force.index,
    id = train_id,
    train = train,
    ignore_schedule = ignore_schedule or false,
  }
  global.trains[train_id] = train_data

  change_train_group(global.trains[train_id], group)
end

--- @param train_data TrainData
local function remove_train(train_data)
  util.log("REMOVE TRAIN: [" .. train_data.id .. "]")
  change_train_group(train_data)
  global.trains[train_data.id] = nil
end

--- @param force_index number
--- @param current_name string
--- @param new_name string
local function rename_group(force_index, current_name, new_name)
  local group_data = global.groups[force_index][current_name]
  if not group_data then
    return
  end

  local force_groups = global.groups[force_index]
  local new_group_data = force_groups[new_name]
  if new_group_data then
    -- Merge with existing group
    for _, train_data in pairs(group_data.trains) do
      change_train_group(train_data, new_name)
    end
  else
    -- Rename group
    group_data.name = new_name
    force_groups[new_name] = group_data
    force_groups[current_name] = nil
    for _, train_data in pairs(group_data.trains) do
      train_data.group = new_name
    end
  end
end

--- @param force_index number
--- @param group string
local function remove_group(force_index, group)
  local group_data = global.groups[force_index][group]
  if not group_data then
    return
  end

  for _, train_data in pairs(group_data.trains) do
    remove_train(train_data)
  end
end

--- @param force_groups table<string, GroupData?>
--- @param old_name string
--- @param new_name string
local function rename_station(force_groups, old_name, new_name)
  for _, group_data in pairs(force_groups) do
    local schedule = group_data.schedule
    if schedule then
      for _, record in pairs(schedule) do
        if record.station and record.station == old_name then
          record.station = new_name
        end
      end
    end
  end
end

--- @param train LuaTrain
--- @param old_id_1 uint?
--- @param old_id_2 uint?
local function migrate_trains(train, old_id_1, old_id_2)
  util.log("MIGRATE TRAIN: [" .. train.id .. "] <- [" .. (old_id_1 or "nil") .. "] [" .. (old_id_2 or "nil") .. "]")
  local added = false
  local schedule = train.schedule
  for _, id in pairs({ old_id_1, old_id_2 }) do
    local train_data = global.trains[id]
    if train_data then
      local group_data = global.groups[train_data.force][train_data.group]
      if
        not added
        and group_data
        and (
          not schedule
          or not group_data.schedule
          or table.deep_compare(sanitize_records(schedule.records), group_data.schedule)
        )
      then
        added = true
        add_train(train, train_data.group, train_data.ignore_schedule)
      end
      global.to_delete[train_data.id] = true
    end
  end
end

--- @param train LuaTrain
local function update_group_schedule(train)
  local train_data = global.trains[train.id]
  if not train_data or train_data.ignore_schedule then
    return
  end

  local group_data = global.groups[train_data.force][train_data.group]
  if not group_data then
    return
  end

  -- Update stored schedule for the group
  util.log("UPDATE SCHEDULE: [" .. train_data.group .. "]")
  local records = train.schedule and sanitize_records(train.schedule.records)
  -- Don't continue if the schedule hasn't actually changed
  if records and group_data.schedule and table.deep_compare(group_data.schedule, records) then
    return
  end
  group_data.schedule = records

  -- Update schedule for all trains in the group
  local to_remove = {}
  for other_id, other_data in pairs(group_data.trains) do
    if other_id ~= train.id then
      if other_data.train.valid then
        local other_train = other_data.train
        local other_train_schedule = other_train.schedule
        if records and #records > 0 then
          other_train.schedule = {
            current = other_train_schedule and math.min(other_train_schedule.current, #records) or 1,
            records = records,
          }
        else
          other_train.schedule = nil
        end
      else
        table.insert(to_remove, other_data)
      end
    end
  end

  -- Remove all invalid trains
  for _, invalid_train_data in pairs(to_remove) do
    util.log("FOUND INVALID TRAIN: [" .. invalid_train_data.id .. "]")
    remove_train(invalid_train_data)
  end
end

--- @param force_index uint
local function auto_create_groups(force_index)
  local force = game.forces[force_index]
  for _, surface in pairs(game.surfaces) do
    for _, train in pairs(surface.get_trains(force)) do
      if global.trains[train.id] then
        goto continue
      end
      local schedule = train.schedule
      if not schedule then
        goto continue
      end
      local group_name = get_schedule_string(schedule.records)
      add_train(train, group_name, true)
      local train_data = global.trains[train.id]
      if not train_data then
        goto continue
      end
      train_data.ignore_schedule = false
      ::continue::
    end
  end
end

--- @param e EventData.on_force_created
local function on_force_created(e)
  init_force(e.force)
end

--- @param e EntityBuiltEvent
local function on_entity_built(e)
  local tags = e.tags
  if not tags or not tags.train_group then
    return
  end

  local entity = e.created_entity or e.entity
  if not entity or not entity.valid then
    return
  end

  add_train(entity.train, tags.train_group --[[@as string?]])
end

--- @param e EventData.on_entity_cloned
local function on_entity_cloned(e)
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

  add_train(destination_train, source_train_data.group)
end

--- @param e EventData.on_pre_entity_settings_pasted
local function on_pre_entity_settings_pasted(e)
  if e.source.type == "locomotive" and e.destination.type == "locomotive" then
    local destination_train = e.destination.train --[[@as LuaTrain]]
    local destination_train_data = global.trains[destination_train.id]
    if destination_train_data then
      -- Add a flag to ignore the schedule change for the destination train
      destination_train_data.ignore_schedule = true
    end
  end
end

--- @param e EventData.on_entity_settings_pasted
local function on_entity_settings_pasted(e)
  local source = e.source
  local destination = e.destination

  if source.type == "locomotive" and destination.type == "locomotive" then
    util.log("SETTINGS PASTED")
    local source_train = source.train --[[@as LuaTrain]]
    local destination_train = destination.train --[[@as LuaTrain]]
    local source_train_data = global.trains[source_train.id]
    local destination_train_data = global.trains[destination_train.id]

    if not source_train_data and destination_train_data then
      remove_train(destination_train_data)
    elseif source_train_data and not destination_train_data then
      add_train(destination_train, source_train_data.group)
    elseif source_train_data and destination_train_data then
      change_train_group(destination_train_data, source_train_data.group)
      destination_train_data.ignore_schedule = false
    end
  end
end

--- @param e EntityDestroyedEvent
local function on_entity_destroyed(e)
  local train = e.entity.train
  if not train then
    return
  end
  util.log(string.upper(table.find(defines.events, e.name)) .. ": [" .. train.id .. "]")
  local train_data = global.trains[train.id]
  if not train_data then
    return
  end
  -- If this is the last rolling stock in the train
  if #train.carriages == 1 then
    remove_train(train_data)
  end
end

local function on_tick()
  for train_id in pairs(global.to_delete) do
    local train_data = global.trains[train_id]
    if train_data then
      remove_train(train_data)
    end
  end
  global.to_delete = {}
end

--- @param e EventData.on_entity_renamed
local function on_entity_renamed(e)
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
    rename_station(force_groups, e.old_name, entity.backer_name)
  end
end

--- @param e EventData.on_train_created
local function on_train_created(e)
  if e.old_train_id_1 or e.old_train_id_2 then
    migrate_trains(e.train, e.old_train_id_1, e.old_train_id_2)
  end
end

--- @param e on_se_train_teleported
local function on_se_elevator_teleport_started(e)
  util.log("ON_TRAIN_TELEPORT_STARTED: [" .. e.old_train_id_1 .. "] -> [" .. e.train.id .. "]")
  local old_train_data = global.trains[e.old_train_id_1]
  if old_train_data then
    old_train_data.ignore_schedule = true
    migrate_trains(e.train, e.old_train_id_1)
  end
end

--- @param e on_se_train_teleported
local function on_se_elevator_teleport_finished(e)
  util.log("ON_TRAIN_TELEPORT_FINISHED: [" .. (e.old_train_id_1 or "") .. "] -> [" .. e.train.id .. "]")
  local train_data = global.trains[e.train.id]
  if train_data then
    train_data.ignore_schedule = false
  end
end

--- @param e EventData.on_train_schedule_changed
local function on_train_schedule_changed(e)
  util.log("ON_TRAIN_SCHEDULE_CHANGED: [" .. e.train.id .. "]")
  -- Only update if a player intentionally changed something
  if e.player_index then
    update_group_schedule(e.train)
  end
end

local rolling_stock_types = {
  ["locomotive"] = true,
  ["cargo-wagon"] = true,
  ["fluid-wagon"] = true,
  ["artillery-wagon"] = true,
}

--- @param e EventData.on_player_setup_blueprint
local function on_player_setup_blueprint(e)
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
end

--- @class GroupsMod
local groups = {}

groups.on_init = function()
  --- @type table<number, table<string, GroupData?>>
  global.groups = {}
  --- @type table<number, boolean>
  global.to_delete = {}
  --- @type table<number, TrainData?>
  global.trains = {}

  for _, force in pairs(game.forces) do
    init_force(force)
  end
end

groups.add_remote_interface = function()
  if
    not script.active_mods["space-exploration"]
    or not remote.interfaces["space-exploration"]["get_on_train_teleport_started_event"]
  then
    return
  end
  local started_event = remote.call("space-exploration", "get_on_train_teleport_started_event")
  groups.events[started_event] = on_se_elevator_teleport_started
  local finished_event = remote.call("space-exploration", "get_on_train_teleport_finished_event")
  groups.events[finished_event] = on_se_elevator_teleport_finished
end

remote.add_interface("TrainGroups", {
  --- @param train_id uint
  --- @return string?
  get_train_group = function(train_id)
    if not global.trains then
      return
    end
    if not train_id then
      error("Call to TrainGroups::get_train_group interface did not provide a train_id")
    end
    local train_data = global.trains[train_id]
    if train_data then
      return train_data.group
    end
  end,
  --- @param train LuaTrain
  --- @param group_name string?
  --- @return string?
  set_train_group = function(train, group_name)
    if not global.trains then
      return
    end
    if not train or not train.valid or train.object_name ~= "LuaTrain" then
      error("Call to TrainGroups::set_train_group interface did not provide a valid train")
    end
    local train_data = global.trains[train.id]
    if train_data and group_name and group_name ~= train_data.group then
      change_train_group(train_data, group_name)
    elseif train_data and not group_name then
      remove_train(train_data)
    elseif group_name and not train_data then
      add_train(train, group_name)
    end
  end,
})

groups.events = {
  [defines.events.on_built_entity] = on_entity_built,
  [defines.events.on_entity_cloned] = on_entity_cloned,
  [defines.events.on_entity_died] = on_entity_destroyed,
  [defines.events.on_entity_renamed] = on_entity_renamed,
  [defines.events.on_entity_settings_pasted] = on_entity_settings_pasted,
  [defines.events.on_force_created] = on_force_created,
  [defines.events.on_player_mined_entity] = on_entity_destroyed,
  [defines.events.on_player_setup_blueprint] = on_player_setup_blueprint,
  [defines.events.on_pre_entity_settings_pasted] = on_pre_entity_settings_pasted,
  [defines.events.on_robot_built_entity] = on_entity_built,
  [defines.events.on_robot_mined_entity] = on_entity_destroyed,
  [defines.events.on_tick] = on_tick,
  [defines.events.on_train_created] = on_train_created,
  [defines.events.on_train_schedule_changed] = on_train_schedule_changed,
  [defines.events.script_raised_built] = on_entity_built,
  [defines.events.script_raised_destroy] = on_entity_destroyed,
  [defines.events.script_raised_revive] = on_entity_built,
}

groups.add_train = add_train
groups.auto_create_groups = auto_create_groups
groups.change_train_group = change_train_group
groups.remove_group = remove_group
groups.remove_train = remove_train
groups.rename_group = rename_group

return groups
