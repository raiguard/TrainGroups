local global_data = {}

local table = require("__flib__.table")

function global_data.init()
  global.networks = {
    ["TESTNETWORK"] = {
      name = "TESTNETWORK",
      colors = {},
      schedule = {},
      trains = {}
    },
    ["TESTNETWORK2"] = {
      name = "TESTNETWORK2",
      colors = {},
      schedule = {},
      trains = {}
    },
  }
  global.opened_locomotives = {}
  global.players = {}
  global.trains = {}
end

function global_data.add_train(train, network)
  local train_id = train.id
  game.print("ADD TRAIN: ["..train.id.."]")

  global.trains[train_id] = {
    id = train_id,
    train = train
  }

  global_data.change_train_network(global.trains[train_id], network)
end

function global_data.remove_train(train_data)
  game.print("REMOVE TRAIN: ["..train_data.id.."]")
  global_data.change_train_network(train_data)
  global.trains[train_data.id] = nil
end

function global_data.change_train_network(train_data, new_network)
  -- remove from old network
  local old_network = train_data.network
  if old_network then
    game.print("CHANGE TRAIN NETWORK: ["..train_data.id.."] | ["..old_network.."] -> ["..(new_network or "").."]")
    -- assume this will exist - if it doesn't, we have bigger problems!
    local network_data = global.networks[old_network]
    local network_trains = network_data.trains
    table.remove(network_trains, table.search(network_trains, train_data.id))
  end
  if new_network then
    -- add to new network
    train_data.network = new_network
    local network_data = global.networks[new_network]
    -- assume this is valid
    local network_trains = network_data.trains
    network_trains[#network_trains+1] = train_data.id
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