## StatSystem - 通用属性系统
## 管理实体属性值和修改器，公式: final = (base + sum_flat) * (1 + sum_percent)
class_name StatSystem
extends Node

# entity_runtime_id -> { stat_name -> base_value }
var _base_stats: Dictionary = {}
# modifier_id -> { entity_id, stat_name, type, value }
var _modifiers: Dictionary = {}
var _next_modifier_id: int = 1

func _ready() -> void:
	EngineAPI.register_system("stat", self)

# === 实体注册 ===

func register_entity(entity: Node2D, base_stats: Dictionary) -> void:
	if not entity is GameEntity:
		return
	var eid: int = (entity as GameEntity).runtime_id
	_base_stats[eid] = base_stats.duplicate()

func unregister_entity(entity: Node2D) -> void:
	if not entity is GameEntity:
		return
	var eid: int = (entity as GameEntity).runtime_id
	_base_stats.erase(eid)
	# 清除该实体的所有修改器
	var to_remove: Array[String] = []
	for mod_id in _modifiers:
		if _modifiers[mod_id]["entity_id"] == eid:
			to_remove.append(mod_id)
	for mod_id in to_remove:
		_modifiers.erase(mod_id)

# === 查询 ===

func get_stat(entity: Node2D, stat_name: String) -> float:
	if not entity is GameEntity:
		return 0.0
	var eid: int = (entity as GameEntity).runtime_id
	var base: float = get_base_stat(entity, stat_name)
	var sum_flat := 0.0
	var sum_percent := 0.0

	for mod: Dictionary in _modifiers.values():
		if mod["entity_id"] == eid and mod["stat_name"] == stat_name:
			if mod["type"] == "flat":
				sum_flat += mod["value"]
			elif mod["type"] == "percent":
				sum_percent += mod["value"]

	return (base + sum_flat) * (1.0 + sum_percent)

func get_base_stat(entity: Node2D, stat_name: String) -> float:
	if not entity is GameEntity:
		return 0.0
	var eid: int = (entity as GameEntity).runtime_id
	if not _base_stats.has(eid):
		return 0.0
	return _base_stats[eid].get(stat_name, 0.0)

func set_base_stat(entity: Node2D, stat_name: String, value: float) -> void:
	if not entity is GameEntity:
		return
	var eid: int = (entity as GameEntity).runtime_id
	if not _base_stats.has(eid):
		_base_stats[eid] = {}
	_base_stats[eid][stat_name] = value

# === 修改器 ===

func add_modifier(entity: Node2D, stat_name: String, modifier: Dictionary) -> String:
	if not entity is GameEntity:
		return ""
	var mod_id := "mod_%d" % _next_modifier_id
	_next_modifier_id += 1
	_modifiers[mod_id] = {
		"entity_id": (entity as GameEntity).runtime_id,
		"stat_name": stat_name,
		"type": modifier.get("type", "flat"),  # "flat" or "percent"
		"value": modifier.get("value", 0.0),
		"source": modifier.get("source", ""),
	}
	return mod_id

func remove_modifier(modifier_id: String) -> void:
	_modifiers.erase(modifier_id)

func get_modifiers_for(entity: Node2D, stat_name: String = "") -> Array[Dictionary]:
	if not entity is GameEntity:
		return []
	var eid: int = (entity as GameEntity).runtime_id
	var result: Array[Dictionary] = []
	for mod_id in _modifiers:
		var mod: Dictionary = _modifiers[mod_id]
		if mod["entity_id"] == eid:
			if stat_name == "" or mod["stat_name"] == stat_name:
				var entry := mod.duplicate()
				entry["modifier_id"] = mod_id
				result.append(entry)
	return result
