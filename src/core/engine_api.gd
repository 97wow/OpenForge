## EngineAPI - 框架公共 API 门面
## 类似 War3 的 native 函数，所有 GamePack 脚本通过此接口与框架交互
## 不包含任何游戏特定逻辑，只做委托
extends Node

# === 游戏状态 ===

var _game_state: String = "idle"
var _variables: Dictionary = {}
var _systems: Dictionary = {}  # system_name -> Node

# === 系统注册 ===

func register_system(name: String, system: Node) -> void:
	_systems[name] = system

func get_system(name: String) -> Node:
	return _systems.get(name)

func has_system(name: String) -> bool:
	return _systems.has(name)

# === 实体 API ===

func spawn_entity(def_id: String, pos: Vector2 = Vector2.ZERO, overrides: Dictionary = {}) -> Node2D:
	var entity_system := get_system("entity") as Node
	if entity_system == null:
		push_error("[EngineAPI] EntitySystem not registered")
		return null
	return entity_system.call("spawn", def_id, pos, overrides)

func destroy_entity(entity: Node2D) -> void:
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

func set_resource(name: String, value: float) -> void:
	var res_system := get_system("resource") as Node
	if res_system:
		res_system.call("set_value", name, value)

func get_resource(name: String) -> float:
	var res_system := get_system("resource") as Node
	if res_system == null:
		return 0.0
	return res_system.call("get_value", name)

func add_resource(name: String, amount: float) -> void:
	var res_system := get_system("resource") as Node
	if res_system:
		res_system.call("add", name, amount)

func subtract_resource(name: String, amount: float) -> bool:
	var res_system := get_system("resource") as Node
	if res_system == null:
		return false
	return res_system.call("subtract", name, amount)

func can_afford(name: String, amount: float) -> bool:
	var res_system := get_system("resource") as Node
	if res_system == null:
		return false
	return res_system.call("can_afford", name, amount)

func define_resource(name: String, initial: float = 0.0, max_val: float = INF) -> void:
	var res_system := get_system("resource") as Node
	if res_system:
		res_system.call("define_resource", name, initial, max_val)

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
	if get_system("stat"):
		get_system("stat").call("remove_modifier", modifier_id)

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

# === UI 工具 ===

func show_message(text: String, duration: float = 3.0) -> void:
	# TODO: 由 UI 系统实现
	print("[Message] %s" % text)

# === 速度控制 ===

func set_time_scale(scale: float) -> void:
	Engine.time_scale = clampf(scale, 0.0, 3.0)

func get_time_scale() -> float:
	return Engine.time_scale
