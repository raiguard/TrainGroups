--- @meta

--- @class on_se_train_teleported: EventData
--- @field train LuaTrain
--- @field old_train_id_1 uint?
--- @field old_surface_index uint
--- @field teleporter LuaEntity

--- @class on_update_train_gui: EventData
--- @field player_index uint

--- @alias EntityBuiltEvent EventData.on_built_entity|EventData.on_robot_built_entity|EventData.script_raised_built|EventData.script_raised_revive
--- @alias EntityDestroyedEvent EventData.on_player_mined_entity|EventData.on_robot_mined_entity|EventData.on_entity_died|EventData.script_raised_destroy
