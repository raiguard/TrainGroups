local global_data = {}

function global_data.init()
  global.networks = {}
  global.players = {}
  global.trains = {}
end

function global_data.migrate_trains(train, old_id_1, old_id_2)
  game.print("MIGRATE TRAIN: ["..train.id.."] <- ["..(old_id_1 or "nil").."] ["..(old_id_2 or "nil").."]")
end

return global_data