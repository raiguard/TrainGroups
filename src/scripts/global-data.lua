local global_data = {}

local table = require("__flib__.table")

function global_data.init()
  global.groups = {
    ["TESTGROUP"] = {
      name = "TESTGROUP",
      colors = {},
      schedule = {},
      trains = {}
    },
    ["TESTGROUP2"] = {
      name = "TESTGROUP2",
      colors = {},
      schedule = {},
      trains = {}
    },
  }
  global.opened_locomotives = {}
  global.players = {}
  global.trains = {}
end

function global_data.add_train(train, group)
  local train_id = train.id
  game.print("ADD TRAIN: ["..train.id.."]")

  global.trains[train_id] = {
    id = train_id,
    train = train
  }

  global_data.change_train_group(global.trains[train_id], group)
end

function global_data.remove_train(train_data)
  game.print("REMOVE TRAIN: ["..train_data.id.."]")
  global_data.change_train_group(train_data)
  global.trains[train_data.id] = nil
end

function global_data.change_train_group(train_data, new_group)
  -- remove from old group
  local old_group = train_data.group
  game.print("CHANGE TRAIN GROUP: ["..train_data.id.."] | ["..(old_group or "").."] -> ["..(new_group or "").."]")
  if old_group then
    -- assume this will exist - if it doesn't, we have bigger problems!
    local group_data = global.groups[old_group]
    local group_trains = group_data.trains
    table.remove(group_trains, table.search(group_trains, train_data.id))
  end
  if new_group then
    -- add to new group
    train_data.group = new_group
    local group_data = global.groups[new_group]
    -- assume this is valid
    local group_trains = group_data.trains
    group_trains[#group_trains+1] = train_data.id
  end
end

function global_data.migrate_trains(train, old_id_1, old_id_2)
  local locomotives = train.locomotives
  if #locomotives.front_movers == 0 and #locomotives.back_movers == 0 then
    for _, id in ipairs{old_id_1, old_id_2} do
      local train_data = global.trains[id]
      if train_data then
        global_data.remove_train(train_data)
      end
    end
  else
    game.print("MIGRATE TRAIN: ["..train.id.."] <- ["..(old_id_1 or "nil").."] ["..(old_id_2 or "nil").."]")
  end
end

return global_data