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
	# AI 状态事件（ThreatManager）
	register_event("ai_entered_combat", "AI进入战斗", ["entity", "aggro"])
	register_event("ai_enter_evade", "AI脱战回家", ["entity"])
	register_event("ai_returned_home", "AI回到出生点", ["entity"])
	# 伤害流水线事件（DamagePipeline）
	register_event("damage_calculating", "伤害计算前(可修改)", ["params"])
	register_event("entity_killed", "实体被击杀", ["entity", "killer", "ability", "overkill"])
	register_event("spell_interrupted", "施法被打断", ["caster", "spell_id"])
	register_event("spell_cast_start", "开始读条", ["caster", "target", "spell_id", "cast_time"])
	register_event("spell_channel_start", "开始引导", ["caster", "target", "spell_id", "channel_time"])
	register_event("spell_channel_tick", "引导tick", ["caster", "target", "spell_id"])

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
	# 防御：先剔失效 callback（freed object），否则下面 `callback not in listeners`
	# 走 Callable == 比较时，对悬空 Object 解引用会段错（跨 GamePack 重载/测试 suite 时高发）
	var has_invalid: bool = false
	for cb: Callable in listeners:
		if not cb.is_valid():
			has_invalid = true
			break
	if has_invalid:
		var valid: Array[Callable] = []
		for cb: Callable in listeners:
			if cb.is_valid():
				valid.append(cb)
		_listeners[event_name] = valid
		listeners = valid
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
		# 框架组件发出的事件（ProcManager/SpellSystem 依赖）
		"projectile_hit", "spell_cast", "aura_applied", "proc_triggered",
		# AI 状态事件（ThreatManager 依赖）
		"ai_entered_combat", "ai_enter_evade", "ai_returned_home",
		# 伤害流水线事件（DamagePipeline 依赖）
		"damage_calculating", "entity_killed", "spell_interrupted",
	]
	var to_remove: Array[String] = []
	for event_name in _listeners:
		if event_name not in core_events:
			to_remove.append(event_name)
		else:
			# 清理 core event 中已失效的 listener（旧 GamePack 的回调）
			var valid_listeners: Array = []
			for cb: Callable in _listeners[event_name]:
				if cb.is_valid():
					valid_listeners.append(cb)
			_listeners[event_name] = valid_listeners
	for event_name in to_remove:
		_listeners.erase(event_name)
		_event_meta.erase(event_name)
