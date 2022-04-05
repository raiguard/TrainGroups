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
  game.print("ADD TRAIN: [" .. train.id .. "]")

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
  game.print("REMOVE TRAIN: [" .. train_data.id .. "]")
  groups.change_train_group(train_data)
  global.trains[train_data.id] = nil
end

--- @param train_data TrainData
--- @param new_group? string
function groups.change_train_group(train_data, new_group)
  -- remove from old group
  local old_group = train_data.group
  game.print(
    "CHANGE TRAIN GROUP: [" .. train_data.id .. "] | [" .. (old_group or "") .. "] -> [" .. (new_group or "") .. "]"
  )
  if old_group then
    -- assume this will exist - if it doesn't, we have bigger problems!
    local group_data = global.groups[train_data.force][old_group]
    local group_trains = group_data.trains
    table.remove(group_trains, table.find(group_trains, train_data.id))

    if #group_data.trains == 0 then
      global.groups[train_data.force][old_group] = nil
      -- TODO: Update all dropdowns
    end
  end
  if new_group then
    -- add to new group
    train_data.group = new_group
    local group_data = global.groups[train_data.force][new_group]
    if not group_data then
      -- Create group data if it doesn't exist
      group_data = {
        name = new_group,
        trains = {},
      }
      global.groups[train_data.force][new_group] = group_data
      -- TODO: Update all dropdowns
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
  if #locomotives.front_movers == 0 and #locomotives.back_movers == 0 then
    -- remove the trains entirely
    for _, id in ipairs({ old_id_1, old_id_2 }) do
      local train_data = global.trains[id]
      if train_data then
        groups.remove_train(train_data)
      end
    end
  else
    game.print("MIGRATE TRAIN: [" .. train.id .. "] <- [" .. (old_id_1 or "nil") .. "] [" .. (old_id_2 or "nil") .. "]")
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
  if train_data and not train_data.updating_schedule then
    local group_data = global.groups[train_data.force][train_data.group]
    if group_data then
      -- update stored schedule for the group
      local train_schedule = train.schedule
      group_data.schedule = train_schedule and train_schedule.records
      -- update schedule for all trains in the group
      for _, train_id in ipairs(group_data.trains) do
        if train_id ~= train.id then
          local other_train_data = global.trains[train_id]
          if other_train_data then
            local other_train = other_train_data.train
            local other_train_schedule = other_train.schedule
            other_train_data.updating_schedule = true
            if train_schedule then
              other_train.schedule = {
                current = other_train_schedule and other_train_schedule.current or 1,
                records = train_schedule.records,
              }
            else
              other_train.schedule = nil
            end
            other_train_data.updating_schedule = nil
          end
        end
      end
    end
  end
end

return groups
