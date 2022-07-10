local event = require("__flib__.event")
local migration = require("__flib__.migration")
local gui_util = require("__flib__.gui")

local gui = require("gui")
local groups = require("groups")

DEBUG = false
function LOG(msg)
  if __DebugAdapter or DEBUG then
    log(msg)
  end
end

-- SPACE EXPLORATION

local function on_se_elevator()
  if script.active_mods["space-exploration"] then
    event.register(
      remote.call("space-exploration", "get_on_train_teleport_started_event"),
      --- @class on_train_teleport_started_event
      --- @field train LuaTrain
      --- @field old_train_id_1 uint
      --- @field old_surface_index uint
      --- @field teleporter LuaEntity
      --- @param e on_train_teleport_started_event
      function(e)
        groups.migrate_trains(e.train, e.old_train_id_1)
      end
    )
  end
end

-- BOOTSTRAP

event.on_init(function()
  on_se_elevator()

  groups.init()

  for _, force in pairs(game.forces) do
    groups.init_force(force)
  end
end)

event.on_load(function()
  on_se_elevator()
end)

event.on_configuration_changed(function(e)
  migration.on_config_changed(e, {
    ["1.0.4"] = function()
      global.to_delete = {}
    end,
    ["1.1.2"] = function()
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
  })
end)

event.on_force_created(function(e)
  groups.init_force(e.force)
end)

-- GUI

gui_util.hook_events(function(e)
  local action = gui_util.read_action(e)
  if action then
    local player = game.get_player(e.player_index)
    -- We probably don't need all of these checks here, but you can't be too safe
    if player.opened_gui_type == defines.gui_type.entity and player.opened and player.opened.type == "locomotive" then
      gui[action](e.element, player.opened.train)
    end
  end
end)

event.on_gui_opened(function(e)
  if e.gui_type == defines.gui_type.entity and e.entity and e.entity.type == "locomotive" then
    gui.build(game.get_player(e.player_index), e.entity.train)
  end
end)

event.on_gui_closed(function(e)
  if e.gui_type == defines.gui_type.entity and e.entity and e.entity.type == "locomotive" then
    gui.destroy(game.get_player(e.player_index))
  end
end)

-- INTERACTION

local rolling_stock_types = {
  ["locomotive"] = true,
  ["cargo-wagon"] = true,
  ["fluid-wagon"] = true,
  ["artillery-wagon"] = true,
}
event.on_player_setup_blueprint(function(e)
  local player = game.get_player(e.player_index)

  -- Get blueprint
  local bp = player.blueprint_to_setup
  if not bp or not bp.valid_for_read then
    bp = player.cursor_stack
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

event.register({
  defines.events.on_built_entity,
  defines.events.on_robot_built_entity,
  defines.events.on_entity_cloned,
  defines.events.script_raised_built,
  defines.events.script_raised_revive,
}, function(e)
  local tags = e.tags
  if not tags or not tags.train_group then
    return
  end

  local entity = e.created_entity or e.entity
  if not entity or not entity.valid then
    return
  end

  groups.add_train(entity.train, tags.train_group)
end, { { filter = "rolling-stock" } })

event.on_pre_entity_settings_pasted(function(e)
  if e.source.type == "locomotive" and e.destination.type == "locomotive" then
    local destination_train = e.destination.train
    local destination_train_data = global.trains[destination_train.id]
    if destination_train_data then
      -- Add a flag to ignore the schedule change for the destination train
      destination_train_data.updating_schedule = true
    end
  end
end)

event.on_entity_settings_pasted(function(e)
  local source = e.source
  local destination = e.destination

  if source.type == "locomotive" and destination.type == "locomotive" then
    LOG("SETTINGS PASTED")

    local source_train = source.train
    local destination_train = destination.train

    local source_train_data = global.trains[source_train.id]
    local destination_train_data = global.trains[destination_train.id]

    if not source_train_data and destination_train_data then
      groups.remove_train(destination_train_data)
    elseif source_train_data and not destination_train_data then
      groups.add_train(destination_train, source_train_data.group)
    elseif source_train_data and destination_train_data then
      groups.change_train_group(destination_train_data, source_train_data.group)
    end
  end
end)

local reverse_defines = require("__flib__.reverse-defines")

event.register({
  defines.events.on_player_mined_entity,
  defines.events.on_robot_mined_entity,
  defines.events.on_entity_died,
  defines.events.script_raised_destroy,
}, function(e)
  LOG("RECEIVED REMOVAL EVENT: " .. reverse_defines.events[e.name])
  local train = e.entity.train
  local train_data = global.trains[train.id]
  if not train_data then
    return
  end

  -- If this is the last rolling stock in the train
  if #train.carriages == 1 then
    groups.remove_train(train_data)
  end
end, { { filter = "rolling-stock" } })

-- TRAIN

event.on_train_created(function(e)
  if e.old_train_id_1 or e.old_train_id_2 then
    groups.migrate_trains(e.train, e.old_train_id_1, e.old_train_id_2)
  end
end)

event.on_train_schedule_changed(function(e)
  -- Only update if a player intentionally changed something
  if e.player_index then
    LOG("SCHEDULE CHANGED")
    groups.update_group_schedule(e.train)
  end
end)

event.on_tick(function()
  for train_id in pairs(global.to_delete) do
    local train_data = global.trains[train_id]
    if train_data then
      groups.remove_train(train_data)
    end
  end
  global.to_delete = {}
end)
