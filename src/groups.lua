local table = require("__flib__.table")

--- @class GroupData
--- @field name string
--- @field schedule TrainSchedule?
--- @field trains number[]

--- @class TrainData
--- @field force number
--- @field group string
--- @field id number
--- @field train LuaTrain
--- @field updating_schedule boolean

--- Remove temporary stations, and remove Train Control Signals skip signal from station names
--- @param records TrainScheduleRecord[]
local function sanitize_records(records)
  local new = {}
  for _, record in pairs(records) do
    if record.station then
      record.station = string.gsub(record.station, "%[virtual%-signal=skip%-signal%]", "")
      table.insert(new, record)
    end
  end
  return new
end

local groups = {}

function groups.init()
  --- @type table<number, table<string, GroupData>>
  global.groups = {}
  --- @type table<number, boolean>
  global.to_delete = {}
  --- @type table<number, TrainData>
  global.trains = {}
end

--- @param force LuaForce
function groups.init_force(force)
  --- @type table<string, GroupData>
  global.groups[force.index] = {}
end

--- @param train LuaTrain
--- @param group string
--- @return TrainData
function groups.add_train(train, group)
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

    train_data.updating_schedule = true
    if group_data.schedule then
      train_data.train.schedule = {
        current = 1,
        records = group_data.schedule,
      }
    else
      train_data.train.schedule = nil
    end
    train_data.updating_schedule = nil
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

  -- Update group name and relocate table
  group_data.name = new_name
  global.groups[force_index][new_name] = group_data
  global.groups[force_index][current_name] = nil

  -- Update all trains in the group
  for _, train_data in pairs(group_data.trains) do
    train_data.group = new_name
  end
end

--- @param train LuaTrain
--- @param old_id_1? number
--- @param old_id_2? number
function groups.migrate_trains(train, old_id_1, old_id_2)
  LOG("MIGRATE TRAIN: [" .. train.id .. "] <- [" .. (old_id_1 or "nil") .. "] [" .. (old_id_2 or "nil") .. "]")
  local added = false
  local schedule = train.schedule
  for _, id in pairs({ old_id_1, old_id_2 }) do
    local train_data = global.trains[id]
    if train_data then
      local group_data = global.groups[train_data.force][train_data.group]
      if group_data and (not group_data.schedule or table.deep_compare(schedule.records, group_data.schedule)) then
        if not added then
          added = true
          groups.add_train(train, train_data.group)
        end
      end
      global.to_delete[train_data.id] = true
    end
  end
end

--- @param train LuaTrain
function groups.update_group_schedule(train)
  local train_data = global.trains[train.id]
  if not train_data or train_data.updating_schedule then
    return
  end

  local group_data = global.groups[train_data.force][train_data.group]
  if not group_data then
    return
  end

  -- Update stored schedule for the group
  local records = train.schedule and sanitize_records(train.schedule.records)
  group_data.schedule = records

  -- Update schedule for all trains in the group
  local to_remove = {}
  for other_id, other_data in pairs(group_data.trains) do
    if other_id ~= train.id then
      if other_data.train.valid then
        local other_train = other_data.train
        local other_train_schedule = other_train.schedule
        other_data.updating_schedule = true
        if records then
          other_train.schedule = {
            current = other_train_schedule and math.min(other_train_schedule.current, #records) or 1,
            records = records,
          }
        else
          other_train.schedule = nil
        end
        other_data.updating_schedule = nil
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

return groups
