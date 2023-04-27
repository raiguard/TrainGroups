local table = require("__flib__/table")

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

--- @class GroupsMod
local groups = {}

function groups.init()
  --- @type table<number, table<string, GroupData?>>
  global.groups = {}
  --- @type table<number, boolean>
  global.to_delete = {}
  --- @type table<number, TrainData?>
  global.trains = {}
end

--- @param force LuaForce
function groups.init_force(force)
  --- @type table<string, GroupData>
  global.groups[force.index] = {}
end

--- @param train LuaTrain
--- @param group string
--- @param ignore_schedule boolean?
--- @return TrainData?
function groups.add_train(train, group, ignore_schedule)
  local train_id = train.id
  if global.trains[train_id] then
    LOG("NOT ADDING TRAIN, DUPLICATE: [" .. train_id .. "]")
    return
  end
  LOG("ADD TRAIN: [" .. train.id .. "]")

  --- @type TrainData
  local train_data = {
    force = train.carriages[1].force.index,
    id = train_id,
    train = train,
    ignore_schedule = ignore_schedule or false,
  }
  global.trains[train_id] = train_data

  groups.change_train_group(global.trains[train_id], group)
end

--- @param train_data TrainData
function groups.remove_train(train_data)
  LOG("REMOVE TRAIN: [" .. train_data.id .. "]")
  groups.change_train_group(train_data)
  global.trains[train_data.id] = nil
end

--- @param train_data TrainData
--- @param new_group? string
function groups.change_train_group(train_data, new_group)
  -- Remove from old group
  local old_group = train_data.group
  LOG("CHANGE TRAIN GROUP: [" .. train_data.id .. "] | [" .. (old_group or "") .. "] -> [" .. (new_group or "") .. "]")
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
    if not train_data.ignore_schedule and group_data.schedule then
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

--- @param force_index number
--- @param current_name string
--- @param new_name string
function groups.rename_group(force_index, current_name, new_name)
  local group_data = global.groups[force_index][current_name]
  if not group_data then
    return
  end

  local force_groups = global.groups[force_index]
  local new_group_data = force_groups[new_name]
  if new_group_data then
    -- Merge with existing group
    for _, train_data in pairs(group_data.trains) do
      groups.change_train_group(train_data, new_name)
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
function groups.remove_group(force_index, group)
  local group_data = global.groups[force_index][group]
  if not group_data then
    return
  end

  for _, train_data in pairs(group_data.trains) do
    groups.remove_train(train_data)
  end
end

--- @param force_groups table<string, GroupData?>
--- @param old_name string
--- @param new_name string
function groups.rename_station(force_groups, old_name, new_name)
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
function groups.migrate_trains(train, old_id_1, old_id_2)
  LOG("MIGRATE TRAIN: [" .. train.id .. "] <- [" .. (old_id_1 or "nil") .. "] [" .. (old_id_2 or "nil") .. "]")
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
        groups.add_train(train, train_data.group, train_data.ignore_schedule)
      end
      global.to_delete[train_data.id] = true
    end
  end
end

--- @param train LuaTrain
function groups.update_group_schedule(train)
  local train_data = global.trains[train.id]
  if not train_data or train_data.ignore_schedule then
    return
  end

  local group_data = global.groups[train_data.force][train_data.group]
  if not group_data then
    return
  end

  -- Update stored schedule for the group
  LOG("UPDATE SCHEDULE: [" .. train_data.group .. "]")
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
    LOG("FOUND INVALID TRAIN: [" .. invalid_train_data.id .. "]")
    groups.remove_train(invalid_train_data)
  end
end

--- @param force_index uint
function groups.auto_create(force_index)
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
      groups.add_train(train, group_name, true)
      local train_data = global.trains[train.id]
      if not train_data then
        goto continue
      end
      train_data.ignore_schedule = false
      ::continue::
    end
  end
end

return groups
