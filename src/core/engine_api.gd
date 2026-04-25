## EngineAPI - 框架公共 API 门面
## 类似 War3 的 native 函数，所有 GamePack 脚本通过此接口与框架交互
## 不包含任何游戏特定逻辑，只做委托
extends Node

# === 物理世界单位参考（1 game unit = 1 meter）===
## 所有空间数值应基于此标准设计：
##   角色身高:      1.8 米
##   近战范围:      2.0 米（手臂+武器长度）
##   短程攻击:      6.0 米（投掷/近射）
##   中程攻击:      5-6 米（弓箭/普通法术）
##   远程攻击:      7-8 米（狙击/强力法术）
##   慢速行走:      0.8 米/秒
##   正常行走:      1.4 米/秒
##   快速行走:      2.0 米/秒
##   慢跑:          3.0-3.5 米/秒
##   跑步:          4.5-5.0 米/秒
##   冲刺:          6.0+ 米/秒
const UNIT_SCALE := 1.0           ## 1 game unit = 1 meter
const REF_CHARACTER_HEIGHT := 1.8  ## 标准角色身高（米）
const REF_MELEE_RANGE := 2.0      ## 标准近战范围
const REF_RANGED_RANGE := 6.0      ## 标准远程范围
const REF_WALK_SPEED := 1.4       ## 标准行走速度
const REF_RUN_SPEED := 4.0        ## 标准跑步速度

# === 游戏状态 ===

var _game_state: String = "idle"
var _variables: Dictionary = {}
var _systems: Dictionary = {}  # system_name -> Node

# === 系统注册 ===

func register_system(sys_name: String, system: Node) -> void:
	_systems[sys_name] = system

func get_system(sys_name: String) -> Node:
	var sys = _systems.get(sys_name)
	if sys == null:
		return null
	if not is_instance_valid(sys):
		_systems.erase(sys_name)
		return null
	if sys is Node and not (sys as Node).is_inside_tree():
		_systems.erase(sys_name)
		return null
	return sys

func has_system(sys_name: String) -> bool:
	return _systems.has(sys_name)

# === 实体 API ===

func spawn_entity(def_id: String, pos: Vector3 = Vector3.ZERO, overrides: Dictionary = {}) -> Node3D:
	var entity_system := get_system("entity") as Node
	if entity_system == null:
		push_error("[EngineAPI] EntitySystem not registered")
		return null
	return entity_system.call("spawn", def_id, pos, overrides)

func destroy_entity(entity: Node3D) -> void:
	if entity == null or not is_instance_valid(entity):
		return
	var entity_system := get_system("entity") as Node
	if entity_system:
		entity_system.call("destroy", entity)

func find_entities_by_tag(tag: String) -> Array:
	var entity_system := get_system("entity") as Node
	if entity_system == null:
		return []
	return entity_system.call("query_by_tag", tag)

func find_entities_in_area(center: Vector3, radius: float, filter_tag: String = "") -> Array:
	var entity_system := get_system("entity") as Node
	if entity_system == null:
		return []
	return entity_system.call("query_in_area", center, radius, filter_tag)

func find_hostiles_in_area(source: Node3D, center: Vector3, radius: float) -> Array:
	## 查找区域内与 source 敌对的实体（基于 faction）
	var entity_system := get_system("entity") as Node
	if entity_system == null or not (source is GameEntity):
		return []
	return entity_system.call("query_hostiles_in_area", source, center, radius)

func find_allies_in_area(source: Node3D, center: Vector3, radius: float) -> Array:
	## 查找区域内与 source 同阵营的实体（基于 faction）
	var entity_system := get_system("entity") as Node
	if entity_system == null or not (source is GameEntity):
		return []
	return entity_system.call("query_allies_in_area", source, center, radius)

func get_entity_by_id(runtime_id: int) -> Node3D:
	var entity_system := get_system("entity") as Node
	if entity_system == null:
		return null
	return entity_system.call("get_by_id", runtime_id)

# === 组件 API ===

func get_component(entity: Node3D, component_name: String) -> Node:
	if entity == null or not entity.has_method("get_component"):
		return null
	return entity.call("get_component", component_name)

func add_component(entity: Node3D, component_name: String, data: Dictionary = {}) -> Node:
	var comp_registry := get_system("component_registry") as Node
	if comp_registry == null:
		return null
	var component: Node = comp_registry.call("create_component", component_name, data)
	if component and entity.has_method("add_component"):
		entity.call("add_component", component_name, component)
	return component

func remove_component(entity: Node3D, component_name: String) -> void:
	if entity and entity.has_method("remove_component"):
		entity.call("remove_component", component_name)

# === 资源 API ===

func set_resource(res_name: String, value: float) -> void:
	var res_system := get_system("resource") as Node
	if res_system:
		res_system.call("set_value", res_name, value)

func get_resource(res_name: String) -> float:
	var res_system := get_system("resource") as Node
	if res_system == null:
		return 0.0
	return res_system.call("get_value", res_name)

func add_resource(res_name: String, amount: float) -> void:
	var res_system := get_system("resource") as Node
	if res_system:
		res_system.call("add", res_name, amount)

func subtract_resource(res_name: String, amount: float) -> bool:
	var res_system := get_system("resource") as Node
	if res_system == null:
		return false
	return res_system.call("subtract", res_name, amount)

func can_afford(res_name: String, amount: float) -> bool:
	var res_system := get_system("resource") as Node
	if res_system == null:
		return false
	return res_system.call("can_afford", res_name, amount)

func define_resource(res_name: String, initial: float = 0.0, max_val: float = INF) -> void:
	var res_system := get_system("resource") as Node
	if res_system:
		res_system.call("define_resource", res_name, initial, max_val)

# === Item API ===

func roll_loot(loot_table_id: String, luck_bonus: float = 0.0) -> Array:
	var item_sys := get_system("item") as Node
	if item_sys == null:
		return []
	return item_sys.call("roll_loot", loot_table_id, luck_bonus)

func equip_item(entity: Node3D, slot: String, item: Dictionary) -> Dictionary:
	var item_sys := get_system("item") as Node
	if item_sys == null:
		return {}
	return item_sys.call("equip_item", entity, slot, item)

func get_equipped(entity: Node3D) -> Dictionary:
	var item_sys := get_system("item") as Node
	if item_sys == null:
		return {}
	return item_sys.call("get_equipped", entity)

# === Inventory API ===

func init_inventory(entity: Node3D, capacity: int = 20) -> void:
	var item_sys := get_system("item") as Node
	if item_sys:
		item_sys.call("init_inventory", entity, capacity)

func inventory_add(entity: Node3D, item: Dictionary) -> bool:
	var item_sys := get_system("item") as Node
	if item_sys == null:
		return false
	return item_sys.call("inventory_add", entity, item)

func inventory_remove(entity: Node3D, index: int) -> Dictionary:
	var item_sys := get_system("item") as Node
	if item_sys == null:
		return {}
	return item_sys.call("inventory_remove", entity, index)

func inventory_get(entity: Node3D) -> Array:
	var item_sys := get_system("item") as Node
	if item_sys == null:
		return []
	return item_sys.call("inventory_get", entity)

func inventory_is_full(entity: Node3D) -> bool:
	var item_sys := get_system("item") as Node
	if item_sys == null:
		return true
	return item_sys.call("inventory_is_full", entity)

func inventory_equip_from(entity: Node3D, idx: int, slot: String) -> bool:
	var item_sys := get_system("item") as Node
	if item_sys == null:
		return false
	return item_sys.call("inventory_equip_from", entity, idx, slot)

func spawn_loot_entity(item: Dictionary, pos: Vector3, lifetime: float = 30.0) -> Node3D:
	var item_sys := get_system("item") as Node
	if item_sys == null:
		return null
	return item_sys.call("spawn_loot_entity", item, pos, lifetime)

# === Spell API ===

func cast_spell(spell_id: String, caster: Node3D, target: Node3D = null, overrides: Dictionary = {}) -> bool:
	var spell_system := get_system("spell") as Node
	if spell_system == null:
		return false
	return spell_system.call("cast", spell_id, caster, target, overrides)

func register_spell(spell_id: String, spell_data: Dictionary) -> void:
	var spell_system := get_system("spell") as Node
	if spell_system:
		spell_system.call("register_spell", spell_id, spell_data)

# === Aura API ===

func apply_spell_aura(caster: Node3D, target: Node3D, aura_type: String, base_points: float, duration: float, spell_id: String = "") -> void:
	var aura_mgr := get_system("aura") as Node
	if aura_mgr:
		aura_mgr.call("apply_aura", caster, target, {
			"aura": aura_type, "base_points": base_points
		}, {"id": spell_id, "school": "physical"}, duration)

func remove_spell_aura(target: Node3D, aura_id: String) -> void:
	var aura_mgr := get_system("aura") as Node
	if aura_mgr:
		aura_mgr.call("remove_aura", target, aura_id)

# === 属性 API ===

func get_stat(entity: Node3D, stat_name: String) -> float:
	var stat_system := get_system("stat") as Node
	if stat_system == null:
		return 0.0
	return stat_system.call("get_stat", entity, stat_name)

# --- 白字/绿字属性 API（War3 风格）---

func add_white_stat(entity: Node3D, stat_name: String, value: float) -> void:
	var stat_system := get_system("stat") as Node
	if stat_system:
		stat_system.call("add_white_stat", entity, stat_name, value)

func add_green_stat(entity: Node3D, stat_name: String, value: float) -> void:
	var stat_system := get_system("stat") as Node
	if stat_system:
		stat_system.call("add_green_stat", entity, stat_name, value)

func add_green_percent(entity: Node3D, stat_name: String, percent: float) -> void:
	var stat_system := get_system("stat") as Node
	if stat_system:
		stat_system.call("add_green_percent", entity, stat_name, percent)

func get_white_stat(entity: Node3D, stat_name: String, level: int = 1) -> float:
	var stat_system := get_system("stat") as Node
	if stat_system == null:
		return 0.0
	return stat_system.call("get_white_stat", entity, stat_name, level)

func get_green_stat(entity: Node3D, stat_name: String) -> float:
	var stat_system := get_system("stat") as Node
	if stat_system == null:
		return 0.0
	return stat_system.call("get_green_stat", entity, stat_name)

func get_total_stat(entity: Node3D, stat_name: String, level: int = 1) -> float:
	var stat_system := get_system("stat") as Node
	if stat_system == null:
		return 0.0
	return stat_system.call("get_total_stat", entity, stat_name, level)

func remove_green_stat(entity: Node3D, stat_name: String, value: float) -> void:
	var stat_system := get_system("stat") as Node
	if stat_system:
		stat_system.call("remove_green_stat", entity, stat_name, value)

func remove_green_percent(entity: Node3D, stat_name: String, percent: float) -> void:
	var stat_system := get_system("stat") as Node
	if stat_system:
		stat_system.call("remove_green_percent", entity, stat_name, percent)

# === 事件 API（委托 EventBus）===

func emit_event(event_name: String, data: Dictionary = {}) -> void:
	EventBus.emit_event(event_name, data)

func connect_event(event_name: String, callback: Callable) -> void:
	EventBus.connect_event(event_name, callback)

func disconnect_event(event_name: String, callback: Callable) -> void:
	EventBus.disconnect_event(event_name, callback)

func register_event(event_name: String, description: String = "", param_names: Array = []) -> void:
	EventBus.register_event(event_name, description, param_names)

# === 触发器 API ===

func register_trigger(trigger_def: Dictionary) -> String:
	var trigger_system := get_system("trigger") as Node
	if trigger_system == null:
		return ""
	return trigger_system.call("register_trigger", trigger_def)

func unregister_trigger(trigger_id: String) -> void:
	var trigger_system := get_system("trigger") as Node
	if trigger_system:
		trigger_system.call("unregister_trigger", trigger_id)

# === Buff API ===

func apply_buff(target: Node3D, buff_id: String, duration: float, data: Dictionary = {}) -> void:
	var buff_system := get_system("buff") as Node
	if buff_system:
		buff_system.call("apply_buff", target, buff_id, duration, data)

func remove_buff(target: Node3D, buff_id: String) -> void:
	var buff_system := get_system("buff") as Node
	if buff_system:
		buff_system.call("remove_buff", target, buff_id)

# === 网格 API（可选系统）===

func grid_to_world(grid_pos: Vector2i) -> Vector3:
	var grid := get_system("grid") as Node
	if grid == null:
		return Vector3(grid_pos.x, 0, grid_pos.y)
	return grid.call("grid_to_world", grid_pos)

func world_to_grid(world_pos: Vector3) -> Vector2i:
	var grid := get_system("grid") as Node
	if grid == null:
		return Vector2i(int(world_pos.x), int(world_pos.z))
	return grid.call("world_to_grid", world_pos)

func get_tile_state(grid_pos: Vector2i) -> String:
	var grid := get_system("grid") as Node
	if grid == null:
		return ""
	return grid.call("get_tile", grid_pos)

func set_tile_state(grid_pos: Vector2i, state: String) -> void:
	var grid := get_system("grid") as Node
	if grid:
		grid.call("set_tile", grid_pos, state)

# === 游戏状态 ===

func set_game_state(new_state: String) -> void:
	var old_state := _game_state
	_game_state = new_state
	EventBus.emit_event("game_state_changed", {
		"old_state": old_state,
		"new_state": new_state,
	})

func get_game_state() -> String:
	return _game_state

# === 通用变量存储（GamePack 运行时状态）===

func set_variable(key: String, value: Variant) -> void:
	var old_value = _variables.get(key)
	_variables[key] = value
	EventBus.emit_event("variable_changed", {
		"key": key,
		"old_value": old_value,
		"new_value": value,
	})

func get_variable(key: String, default: Variant = null) -> Variant:
	return _variables.get(key, default)

func has_variable(key: String) -> bool:
	return _variables.has(key)

func clear_variables() -> void:
	_variables.clear()

func reset_all_state() -> void:
	## 重置所有框架状态（新局开始前调用）
	_game_state = "idle"
	_variables.clear()
	# 清理所有子系统状态
	var aura_mgr := get_system("aura")
	if aura_mgr and aura_mgr.has_method("_reset"):
		aura_mgr.call("_reset")
	var proc_mgr := get_system("proc")
	if proc_mgr and proc_mgr.has_method("_reset"):
		proc_mgr.call("_reset")
	var stat_sys := get_system("stat")
	if stat_sys and stat_sys.has_method("_reset"):
		stat_sys.call("_reset")
	var res_sys := get_system("resource")
	if res_sys and res_sys.has_method("clear_all"):
		res_sys.call("clear_all")
	var spell_sys := get_system("spell")
	if spell_sys and spell_sys.has_method("_reset"):
		spell_sys.call("_reset")
	var item_sys := get_system("item")
	if item_sys and item_sys.has_method("_reset"):
		item_sys.call("_reset")
	var threat_mgr := get_system("threat")
	if threat_mgr and threat_mgr.has_method("_reset"):
		threat_mgr.call("_reset")
	var area_aura_sys := get_system("area_aura")
	if area_aura_sys and area_aura_sys.has_method("_reset"):
		area_aura_sys.call("_reset")
	var immunity_sys := get_system("immunity")
	if immunity_sys and immunity_sys.has_method("_reset"):
		immunity_sys.call("_reset")
	var respawn_sys := get_system("respawn")
	if respawn_sys and respawn_sys.has_method("_reset"):
		respawn_sys.call("_reset")
	var faction_sys := get_system("faction")
	if faction_sys and faction_sys.has_method("_reset"):
		faction_sys.call("_reset")
	var move_gen := get_system("movement_gen")
	if move_gen and move_gen.has_method("_reset"):
		move_gen.call("_reset")
	var sel_sys := get_system("selection")
	if sel_sys and sel_sys.has_method("_reset"):
		sel_sys.call("_reset")
	for sys_name in ["dr", "encounter", "quest", "achievement", "pathfinding", "network", "room", "chat", "replay", "level", "dialogue", "audio"]:
		var sys := get_system(sys_name)
		if sys and sys.has_method("_reset"):
			sys.call("_reset")
	EventBus.clear_all_custom_events()
	DataRegistry.clear_all()
	print("[EngineAPI] All state reset")

# === Area Aura API ===

func create_area_aura(params: Dictionary) -> int:
	var area_sys := get_system("area_aura") as Node
	if area_sys == null:
		return -1
	return area_sys.call("create_area_aura", params)

func destroy_area_aura(area_id: int) -> void:
	var area_sys := get_system("area_aura") as Node
	if area_sys:
		area_sys.call("destroy_area_aura", area_id)

func get_area_aura(area_id: int) -> Dictionary:
	var area_sys := get_system("area_aura") as Node
	if area_sys == null:
		return {}
	return area_sys.call("get_area_aura", area_id)

# === Immunity API ===

func grant_school_immunity(entity: Node3D, school_mask: int, source_id: String = "") -> void:
	var imm_sys := get_system("immunity") as Node
	if imm_sys and entity is GameEntity:
		imm_sys.call("grant_school_immunity", entity, school_mask, source_id)

func revoke_school_immunity(entity: Node3D, source_id: String = "") -> void:
	var imm_sys := get_system("immunity") as Node
	if imm_sys and entity is GameEntity:
		imm_sys.call("revoke_school_immunity", entity, source_id)

func is_immune_to_school(entity: Node3D, school: int) -> bool:
	var imm_sys := get_system("immunity") as Node
	if imm_sys and entity is GameEntity:
		return imm_sys.call("is_immune_to_school", entity, school)
	return false

func grant_mechanic_immunity(entity: Node3D, mechanic: String, source_id: String = "") -> void:
	var imm_sys := get_system("immunity") as Node
	if imm_sys and entity is GameEntity:
		imm_sys.call("grant_mechanic_immunity", entity, mechanic, source_id)

func revoke_mechanic_immunity(entity: Node3D, mechanic: String, source_id: String = "") -> void:
	var imm_sys := get_system("immunity") as Node
	if imm_sys and entity is GameEntity:
		imm_sys.call("revoke_mechanic_immunity", entity, mechanic, source_id)

func is_immune_to_mechanic(entity: Node3D, mechanic: String) -> bool:
	var imm_sys := get_system("immunity") as Node
	if imm_sys and entity is GameEntity:
		return imm_sys.call("is_immune_to_mechanic", entity, mechanic)
	return false

# === Respawn API ===

func register_spawn_group(group_def: Dictionary) -> String:
	var respawn_sys := get_system("respawn") as Node
	if respawn_sys == null:
		return ""
	return respawn_sys.call("register_spawn_group", group_def)

func spawn_group(group_id: String) -> Array:
	var respawn_sys := get_system("respawn") as Node
	if respawn_sys == null:
		return []
	return respawn_sys.call("spawn_group", group_id)

func despawn_group(group_id: String) -> void:
	var respawn_sys := get_system("respawn") as Node
	if respawn_sys:
		respawn_sys.call("despawn_group", group_id)

# === Faction API ===

func register_faction(faction_def: Dictionary) -> void:
	var faction_sys := get_system("faction") as Node
	if faction_sys:
		faction_sys.call("register_faction", faction_def)

func get_faction_reaction(faction_a: String, faction_b: String) -> int:
	var faction_sys := get_system("faction") as Node
	if faction_sys:
		return faction_sys.call("get_reaction", faction_a, faction_b)
	return 2  # NEUTRAL

func set_faction_reaction(faction_a: String, faction_b: String, reaction: int) -> void:
	var faction_sys := get_system("faction") as Node
	if faction_sys:
		faction_sys.call("set_reaction_override", faction_a, faction_b, reaction)


func add_reputation(player_id: String, faction_id: String, amount: float) -> void:
	var faction_sys := get_system("faction") as Node
	if faction_sys:
		faction_sys.call("add_reputation", player_id, faction_id, amount)

func get_reputation(player_id: String, faction_id: String) -> float:
	var faction_sys := get_system("faction") as Node
	if faction_sys:
		return faction_sys.call("get_reputation", player_id, faction_id)
	return 0.0

# === Movement Generator API ===

func push_movement(entity: Node3D, move_type: int, params: Dictionary = {}) -> void:
	var move_gen := get_system("movement_gen") as Node
	if move_gen and entity is GameEntity:
		move_gen.call("push_movement", entity, move_type, params)

func pop_movement(entity: Node3D, move_type: int) -> void:
	var move_gen := get_system("movement_gen") as Node
	if move_gen and entity is GameEntity:
		move_gen.call("pop_movement", entity, move_type)

func move_chase(entity: Node3D, target: Node3D, arrive_dist: float = 30.0) -> void:
	var move_gen := get_system("movement_gen") as Node
	if move_gen and entity is GameEntity and target is GameEntity:
		move_gen.call("move_chase", entity, target, arrive_dist)

func move_flee(entity: Node3D, from_target: Node3D, duration: float = 3.0) -> void:
	var move_gen := get_system("movement_gen") as Node
	if move_gen and entity is GameEntity and from_target is GameEntity:
		move_gen.call("move_flee", entity, from_target, duration)

func move_point(entity: Node3D, target_pos: Vector3) -> void:
	var move_gen := get_system("movement_gen") as Node
	if move_gen and entity is GameEntity:
		move_gen.call("move_point", entity, target_pos)

# === Level API ===

func init_level(entity: Node3D, params: Dictionary = {}) -> void:
	var level_sys := get_system("level") as Node
	if level_sys and entity is GameEntity:
		level_sys.call("init_level", entity, params)

func add_xp(entity: Node3D, amount: int) -> void:
	var level_sys := get_system("level") as Node
	if level_sys and entity is GameEntity:
		level_sys.call("add_xp", entity, amount)

func get_level(entity: Node3D) -> int:
	var level_sys := get_system("level") as Node
	if level_sys and entity is GameEntity:
		return level_sys.call("get_level", entity)
	return 1

# === Dialogue API ===

func start_dialogue(dialogue_id: String, speaker: Node3D = null) -> bool:
	var dlg_sys := get_system("dialogue") as Node
	if dlg_sys == null:
		return false
	return dlg_sys.call("start_dialogue", dialogue_id, speaker)

func select_dialogue_option(index: int) -> void:
	var dlg_sys := get_system("dialogue") as Node
	if dlg_sys:
		dlg_sys.call("select_option", index)

func end_dialogue() -> void:
	var dlg_sys := get_system("dialogue") as Node
	if dlg_sys:
		dlg_sys.call("end_dialogue")

# === Camera API ===

func camera_follow(target: Node3D, smoothing: float = 5.0) -> void:
	var cam := get_system("camera") as Node
	if cam:
		cam.call("follow", target, smoothing)

func camera_shake(intensity: float = 8.0) -> void:
	var cam := get_system("camera") as Node
	if cam:
		cam.call("shake", intensity)

func camera_zoom(level: float) -> void:
	var cam := get_system("camera") as Node
	if cam:
		cam.call("set_zoom_level", level)

func camera_move_to(pos: Vector3, duration: float = 0.5) -> void:
	var cam := get_system("camera") as Node
	if cam:
		cam.call("move_to", pos, duration)

# === Selection API ===

func select_entity(entity: Node3D) -> void:
	var sel := get_system("selection") as Node
	if sel: sel.call("select_entity", entity)

func deselect_entity() -> void:
	var sel := get_system("selection") as Node
	if sel: sel.call("deselect")

func get_selected_entity() -> Node3D:
	var sel := get_system("selection") as Node
	if sel and sel.has_method("get_selected_entity"):
		return sel.call("get_selected_entity")
	return null

# === Audio API ===

func play_bgm(path: String, fade_in: float = 1.0) -> void:
	var audio := get_system("audio") as Node
	if audio:
		audio.call("play_bgm", path, fade_in)

func stop_bgm(fade_out: float = 1.0) -> void:
	var audio := get_system("audio") as Node
	if audio:
		audio.call("stop_bgm", fade_out)

func play_sfx(path: String, volume: float = 1.0) -> void:
	var audio := get_system("audio") as Node
	if audio:
		audio.call("play_sfx", path, volume)

func set_audio_volume(group: String, volume: float) -> void:
	var audio := get_system("audio") as Node
	if audio:
		audio.call("set_volume", group, volume)

# === Encounter API ===

func create_encounter(params: Dictionary) -> int:
	var enc_sys := get_system("encounter") as Node
	if enc_sys == null:
		return -1
	return enc_sys.call("create_encounter", params)

func start_encounter(encounter_id: int) -> void:
	var enc_sys := get_system("encounter") as Node
	if enc_sys:
		enc_sys.call("start_encounter", encounter_id)

func set_encounter_phase(encounter_id: int, phase: int) -> void:
	var enc_sys := get_system("encounter") as Node
	if enc_sys:
		enc_sys.call("set_phase", encounter_id, phase)

func schedule_encounter_timer(encounter_id: int, timer_name: String, delay: float, callback: Callable, repeat: bool = false) -> void:
	var enc_sys := get_system("encounter") as Node
	if enc_sys:
		enc_sys.call("schedule_timer", encounter_id, timer_name, delay, callback, repeat)

# === Quest API ===

func accept_quest(player_id: String, quest_id: String) -> bool:
	var quest_sys := get_system("quest") as Node
	if quest_sys == null:
		return false
	return quest_sys.call("accept_quest", player_id, quest_id)

func turn_in_quest(player_id: String, quest_id: String) -> bool:
	var quest_sys := get_system("quest") as Node
	if quest_sys == null:
		return false
	return quest_sys.call("turn_in_quest", player_id, quest_id)

func get_active_quests(player_id: String) -> Array:
	var quest_sys := get_system("quest") as Node
	if quest_sys == null:
		return []
	return quest_sys.call("get_active_quests", player_id)

# === Pathfinding API ===

func find_nav_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var path_sys := get_system("pathfinding") as Node
	if path_sys == null:
		return PackedVector3Array([from, to])
	return path_sys.call("find_path", from, to)

func get_nav_direction(entity: Node3D, target_pos: Vector3) -> Vector3:
	var path_sys := get_system("pathfinding") as Node
	if path_sys and entity is GameEntity:
		return path_sys.call("get_direction", entity, target_pos)
	return entity.global_position.direction_to(target_pos) if is_instance_valid(entity) else Vector3.ZERO

# === Damage Pipeline API ===

func deal_damage(params: Dictionary) -> Dictionary:
	return DamagePipeline.deal_damage(params)

# === Threat API（仇恨系统）===

func add_threat(entity: Node3D, source: Node3D, amount: float) -> void:
	var threat: Node = get_system("threat")
	if threat and entity is GameEntity and source is GameEntity:
		threat.call("add_threat", entity, source, amount)

func get_threat_victim(entity: Node3D) -> Node3D:
	var threat: Node = get_system("threat")
	if threat and entity is GameEntity:
		return threat.call("get_victim", entity)
	return null

func apply_taunt(entity: Node3D, taunter: Node3D, duration: float) -> void:
	var threat: Node = get_system("threat")
	if threat and entity is GameEntity and taunter is GameEntity:
		threat.call("apply_taunt", entity, taunter, duration)

# === I18n 代理（确保动态加载的脚本也能访问）===

static func t(key: String, args: Array = []) -> String:
	## 翻译代理：GamePack 脚本可通过 EngineAPI.t() 访问
	var i18n: Node = Engine.get_main_loop().root.get_node_or_null("I18n") if Engine.get_main_loop() else null
	if i18n and i18n.has_method("t"):
		return i18n.call("t", key, args)
	return key

# === UI 工具 ===

func show_message(text: String, _duration: float = 3.0) -> void:
	# TODO: 由 UI 系统实现
	print("[Message] %s" % text)

# === 速度控制 ===

func set_time_scale(scale: float) -> void:
	Engine.time_scale = clampf(scale, 0.0, 3.0)

func get_time_scale() -> float:
	return Engine.time_scale
