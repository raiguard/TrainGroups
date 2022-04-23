local table = require("__flib__.table")
local train_util = require("__flib__.train")

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
  LOG("ADD TRAIN: [" .. train.id .. "]")

  --- @type TrainData
  local train_data = {
    force = train_util.get_main_locomotive(train).force.index,
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
    -- Assume this will exist - if it doesn't, we have bigger problems!
    local group_data = global.groups[train_data.force][old_group]
    local group_trains = group_data.trains
    table.remove(group_trains, table.find(group_trains, train_data.id))

    if #group_data.trains == 0 then
      global.groups[train_data.force][old_group] = nil
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
    group_trains[#group_trains + 1] = train_data.id

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

--- @param train LuaTrain
--- @param old_id_1? number
--- @param old_id_2? number
function groups.migrate_trains(train, old_id_1, old_id_2)
  local locomotives = train.locomotives
  if #locomotives.front_movers > 0 or #locomotives.back_movers > 0 then
    LOG("MIGRATE TRAIN: [" .. train.id .. "] <- [" .. (old_id_1 or "nil") .. "] [" .. (old_id_2 or "nil") .. "]")
    local added = false
    local schedule = train.schedule
    for _, id in ipairs({ old_id_1, old_id_2 }) do
      local train_data = global.trains[id]
      if train_data then
        local group_data = global.groups[train_data.force][train_data.group]
        if group_data and (not group_data.schedule or table.deep_compare(schedule.records, group_data.schedule)) then
          if not added then
            added = true
            groups.add_train(train, train_data.group)
          end
        end
        groups.remove_train(train_data)
      end
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
  for _, other_id in ipairs(group_data.trains) do
    if other_id ~= train.id then
      local other_train_data = global.trains[other_id]
      if other_train_data then
        if other_train_data.train.valid then
          local other_train = other_train_data.train
          local other_train_schedule = other_train.schedule
          other_train_data.updating_schedule = true
          if records then
            other_train.schedule = {
              current = other_train_schedule and math.min(other_train_schedule.current, #records) or 1,
              records = records,
            }
          else
            other_train.schedule = nil
          end
          other_train_data.updating_schedule = nil
        else
          table.insert(to_remove, other_train_data)
        end
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
