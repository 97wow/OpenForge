## EventBus - 动态事件总线
## 所有事件在运行时注册，框架不硬编码任何游戏特定信号
## GamePack 通过 register_event() 注册自定义事件
extends Node

# 内部存储: event_name -> Array[Callable]
var _listeners: Dictionary = {}
# 事件元数据: event_name -> { description, param_names }
var _event_meta: Dictionary = {}
# 调试模式
var debug_mode: bool = false

func _ready() -> void:
	# 框架生命周期事件（唯一硬编码的事件，因为它们属于框架本身）
	register_event("engine_ready", "框架初始化完成")
	register_event("entity_spawned", "实体创建", ["entity"])
	register_event("entity_destroyed", "实体销毁", ["entity"])
	register_event("entity_damaged", "实体受伤", ["entity", "amount", "source"])
	register_event("entity_healed", "实体治愈", ["entity", "amount", "source"])
	register_event("resource_changed", "资源变更", ["resource", "old_value", "new_value", "delta"])
	register_event("game_state_changed", "游戏状态变更", ["old_state", "new_state"])
	register_event("variable_changed", "变量变更", ["key", "old_value", "new_value"])
	register_event("gamepack_loaded", "GamePack加载完成", ["pack_id"])
	register_event("gamepack_unloaded", "GamePack卸载", ["pack_id"])
	register_event("trigger_fired", "触发器触发", ["trigger_id", "event_name"])

# === 事件注册 ===

func register_event(event_name: String, description: String = "", param_names: Array = []) -> void:
	if not _listeners.has(event_name):
		_listeners[event_name] = [] as Array[Callable]
	_event_meta[event_name] = {
		"description": description,
		"param_names": param_names,
	}
	if debug_mode:
		print("[EventBus] Registered: %s" % event_name)

func unregister_event(event_name: String) -> void:
	_listeners.erase(event_name)
	_event_meta.erase(event_name)

func has_event(event_name: String) -> bool:
	return _listeners.has(event_name)

# === 监听 ===

func connect_event(event_name: String, callback: Callable) -> void:
	if not _listeners.has(event_name):
		register_event(event_name)
	var listeners: Array = _listeners[event_name]
	if callback not in listeners:
		listeners.append(callback)

func disconnect_event(event_name: String, callback: Callable) -> void:
	if not _listeners.has(event_name):
		return
	var listeners: Array = _listeners[event_name]
	var idx := listeners.find(callback)
	if idx >= 0:
		listeners.remove_at(idx)

# === 触发 ===

func emit_event(event_name: String, data: Dictionary = {}) -> void:
	if debug_mode:
		print("[EventBus] Emit: %s %s" % [event_name, data])
	if not _listeners.has(event_name):
		if debug_mode:
			push_warning("[EventBus] No listeners for '%s'" % event_name)
		return
	var listeners := _listeners[event_name].duplicate() as Array
	for callback: Callable in listeners:
		if not callback.is_valid():
			continue
		callback.call(data)

# === 查询 ===

func get_registered_events() -> Array[String]:
	var result: Array[String] = []
	for key in _listeners:
		result.append(key)
	return result

func get_event_meta(event_name: String) -> Dictionary:
	return _event_meta.get(event_name, {})

func get_listener_count(event_name: String) -> int:
	if not _listeners.has(event_name):
		return 0
	return _listeners[event_name].size()

# === 批量操作 ===

func clear_listeners(event_name: String) -> void:
	if _listeners.has(event_name):
		_listeners[event_name].clear()

func clear_all_custom_events() -> void:
	var core_events := [
		"engine_ready", "entity_spawned", "entity_destroyed",
		"entity_damaged", "entity_healed", "resource_changed",
		"game_state_changed", "variable_changed",
		"gamepack_loaded", "gamepack_unloaded", "trigger_fired",
	]
	var to_remove: Array[String] = []
	for event_name in _listeners:
		if event_name not in core_events:
			to_remove.append(event_name)
	for event_name in to_remove:
		_listeners.erase(event_name)
		_event_meta.erase(event_name)
