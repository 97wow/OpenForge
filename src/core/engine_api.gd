## EngineAPI - 框架公共 API 门面
## 类似 War3 的 native 函数，所有 GamePack 脚本通过此接口与框架交互
## 不包含任何游戏特定逻辑，只做委托
extends Node

# === 游戏状态 ===

var _game_state: String = "idle"
var _variables: Dictionary = {}
var _systems: Dictionary = {}  # system_name -> Node

# === 系统注册 ===

func register_system(sys_name: String, system: Node) -> void:
	_systems[sys_name] = system

func get_system(sys_name: String) -> Node:
	return _systems.get(sys_name)

func has_system(sys_name: String) -> bool:
	return _systems.has(sys_name)

# === 实体 API ===

func spawn_entity(def_id: String, pos: Vector2 = Vector2.ZERO, overrides: Dictionary = {}) -> Node2D:
	var entity_system := get_system("entity") as Node
	if entity_system == null:
		push_error("[EngineAPI] EntitySystem not registered")
		return null
	return entity_system.call("spawn", def_id, pos, overrides)

func destroy_entity(entity: Node2D) -> void:
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

func find_entities_in_area(center: Vector2, radius: float, filter_tag: String = "") -> Array:
	var entity_system := get_system("entity") as Node
	if entity_system == null:
		return []
	return entity_system.call("query_in_area", center, radius, filter_tag)

func get_entity_by_id(runtime_id: int) -> Node2D:
	var entity_system := get_system("entity") as Node
	if entity_system == null:
		return null
	return entity_system.call("get_by_id", runtime_id)

# === 组件 API ===

func get_component(entity: Node2D, component_name: String) -> Node:
	if entity == null or not entity.has_method("get_component"):
		return null
	return entity.call("get_component", component_name)

func add_component(entity: Node2D, component_name: String, data: Dictionary = {}) -> Node:
	var comp_registry := get_system("component_registry") as Node
	if comp_registry == null:
		return null
	var component: Node = comp_registry.call("create_component", component_name, data)
	if component and entity.has_method("add_component"):
		entity.call("add_component", component_name, component)
	return component

func remove_component(entity: Node2D, component_name: String) -> void:
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

func equip_item(entity: Node2D, slot: String, item: Dictionary) -> Dictionary:
	var item_sys := get_system("item") as Node
	if item_sys == null:
		return {}
	return item_sys.call("equip_item", entity, slot, item)

func get_equipped(entity: Node2D) -> Dictionary:
	var item_sys := get_system("item") as Node
	if item_sys == null:
		return {}
	return item_sys.call("get_equipped", entity)

# === Spell API ===

func cast_spell(spell_id: String, caster: Node2D, target: Node2D = null, overrides: Dictionary = {}) -> bool:
	var spell_system := get_system("spell") as Node
	if spell_system == null:
		return false
	return spell_system.call("cast", spell_id, caster, target, overrides)

func register_spell(spell_id: String, spell_data: Dictionary) -> void:
	var spell_system := get_system("spell") as Node
	if spell_system:
		spell_system.call("register_spell", spell_id, spell_data)

# === Aura API ===

func apply_spell_aura(caster: Node2D, target: Node2D, aura_type: String, base_points: float, duration: float, spell_id: String = "") -> void:
	var aura_mgr := get_system("aura") as Node
	if aura_mgr:
		aura_mgr.call("apply_aura", caster, target, {
			"aura": aura_type, "base_points": base_points
		}, {"id": spell_id, "school": "physical"}, duration)

func remove_spell_aura(target: Node2D, aura_id: String) -> void:
	var aura_mgr := get_system("aura") as Node
	if aura_mgr:
		aura_mgr.call("remove_aura", target, aura_id)

# === 属性 API ===

func get_stat(entity: Node2D, stat_name: String) -> float:
	var stat_system := get_system("stat") as Node
	if stat_system == null:
		return 0.0
	return stat_system.call("get_stat", entity, stat_name)

func add_stat_modifier(entity: Node2D, stat_name: String, modifier: Dictionary) -> String:
	var stat_system := get_system("stat") as Node
	if stat_system == null:
		return ""
	return stat_system.call("add_modifier", entity, stat_name, modifier)

func remove_stat_modifier(modifier_id: String) -> void:
	var stat_system := get_system("stat") as Node
	if stat_system:
		stat_system.call("remove_modifier", modifier_id)

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

func apply_buff(target: Node2D, buff_id: String, duration: float, data: Dictionary = {}) -> void:
	var buff_system := get_system("buff") as Node
	if buff_system:
		buff_system.call("apply_buff", target, buff_id, duration, data)

func remove_buff(target: Node2D, buff_id: String) -> void:
	var buff_system := get_system("buff") as Node
	if buff_system:
		buff_system.call("remove_buff", target, buff_id)

# === 网格 API（可选系统）===

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var grid := get_system("grid") as Node
	if grid == null:
		return Vector2(grid_pos)
	return grid.call("grid_to_world", grid_pos)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var grid := get_system("grid") as Node
	if grid == null:
		return Vector2i(world_pos)
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
	EventBus.clear_all_custom_events()
	DataRegistry.clear_all()
	print("[EngineAPI] All state reset")

# === UI 工具 ===

func show_message(text: String, _duration: float = 3.0) -> void:
	# TODO: 由 UI 系统实现
	print("[Message] %s" % text)

# === 速度控制 ===

func set_time_scale(scale: float) -> void:
	Engine.time_scale = clampf(scale, 0.0, 3.0)

func get_time_scale() -> float:
	return Engine.time_scale
