## RespawnSystem — 重生/刷新管理（对标 TrinityCore SpawnGroup + CreatureRespawn）
## 管理实体死亡后的定时重生、刷新组、条件刷新
## 框架层系统，零游戏知识。GamePack 定义刷新组和规则。
class_name RespawnSystem
extends Node

# === 数据存储 ===

# 刷新组定义: group_id -> SpawnGroupDef
# SpawnGroupDef: {
#   "group_id": String,
#   "entries": [{ "def_id": String, "position": Vector2, "overrides": Dictionary }],
#   "respawn_time": float,       # 重生延迟（秒）
#   "max_alive": int,            # 最大同时存活数（0=无限）
#   "condition": Dictionary,     # 可选条件 { "type": "event"|"timer"|"kill_count", ... }
#   "enabled": bool,
# }
var _spawn_groups: Dictionary = {}

# 活跃的重生计时器: timer_id -> RespawnTimer
# RespawnTimer: {
#   "group_id": String,
#   "entry_index": int,          # -1 表示整组重生
#   "remaining": float,
#   "entry": Dictionary,         # 缓存的 entry 数据
# }
var _respawn_timers: Dictionary = {}
var _next_timer_id: int = 1

# 刷新组已生成的实体跟踪: group_id -> [runtime_id, ...]
var _group_entities: Dictionary = {}

func _ready() -> void:
	EngineAPI.register_system("respawn", self)
	EventBus.connect_event("entity_killed", _on_entity_killed)
	EventBus.connect_event("entity_destroyed", _on_entity_destroyed)

func _process(delta: float) -> void:
	if EngineAPI.get_game_state() != "playing":
		return
	_tick_timers(delta)

func _reset() -> void:
	_spawn_groups.clear()
	_respawn_timers.clear()
	_group_entities.clear()
	_next_timer_id = 1

# === 公共 API ===

func register_spawn_group(group_def: Dictionary) -> String:
	## 注册一个刷新组（通常在地图加载时调用）
	var group_id: String = group_def.get("group_id", "")
	if group_id == "":
		group_id = "group_%d" % _next_timer_id
		_next_timer_id += 1
		group_def["group_id"] = group_id
	if not group_def.has("enabled"):
		group_def["enabled"] = true
	if not group_def.has("respawn_time"):
		group_def["respawn_time"] = 30.0
	if not group_def.has("max_alive"):
		group_def["max_alive"] = 0
	_spawn_groups[group_id] = group_def
	_group_entities[group_id] = []
	return group_id

func spawn_group(group_id: String) -> Array[GameEntity]:
	## 立即生成整个刷新组的所有实体
	var group: Dictionary = _spawn_groups.get(group_id, {})
	if group.is_empty():
		return []
	if not group.get("enabled", true):
		return []
	var entries: Array = group.get("entries", [])
	var max_alive: int = group.get("max_alive", 0)
	var spawned: Array[GameEntity] = []
	for i in range(entries.size()):
		if max_alive > 0 and _count_alive(group_id) >= max_alive:
			break
		var entity: GameEntity = _spawn_entry(group_id, entries[i])
		if entity:
			spawned.append(entity)
	EventBus.emit_event("spawn_group_spawned", {
		"group_id": group_id, "count": spawned.size(),
	})
	return spawned

func despawn_group(group_id: String) -> void:
	## 销毁刷新组的所有活着的实体
	if not _group_entities.has(group_id):
		return
	var ids: Array = _group_entities[group_id].duplicate()
	for rid in ids:
		var entity: Node3D = EngineAPI.get_entity_by_id(rid)
		if entity and is_instance_valid(entity):
			EngineAPI.destroy_entity(entity)
	_group_entities[group_id].clear()
	# 清除相关的重生计时器
	var timers_to_remove: Array = []
	for tid in _respawn_timers:
		if _respawn_timers[tid].get("group_id", "") == group_id:
			timers_to_remove.append(tid)
	for tid in timers_to_remove:
		_respawn_timers.erase(tid)

func set_group_enabled(group_id: String, enabled: bool) -> void:
	if _spawn_groups.has(group_id):
		_spawn_groups[group_id]["enabled"] = enabled
		if not enabled:
			despawn_group(group_id)

func get_spawn_group(group_id: String) -> Dictionary:
	return _spawn_groups.get(group_id, {})

func get_group_alive_count(group_id: String) -> int:
	return _count_alive(group_id)

func get_pending_respawns() -> Array[Dictionary]:
	## 返回所有正在倒计时的重生条目（用于 UI/调试）
	var result: Array[Dictionary] = []
	for tid in _respawn_timers:
		var t: Dictionary = _respawn_timers[tid]
		result.append({
			"group_id": t.get("group_id", ""),
			"remaining": t.get("remaining", 0.0),
			"def_id": t.get("entry", {}).get("def_id", ""),
		})
	return result

func force_respawn(group_id: String) -> void:
	## 强制立即重生该组所有待重生的实体（跳过计时器）
	var timers_to_fire: Array = []
	for tid in _respawn_timers:
		if _respawn_timers[tid].get("group_id", "") == group_id:
			timers_to_fire.append(tid)
	for tid in timers_to_fire:
		_fire_respawn(tid)

# === 内部逻辑 ===

func _spawn_entry(group_id: String, entry: Dictionary) -> GameEntity:
	## 生成单个刷新组条目
	var def_id: String = entry.get("def_id", "")
	if def_id == "":
		return null
	var pos: Vector3 = Vector3(
		entry.get("position_x", entry.get("position", Vector3.ZERO).x),
		0,
		entry.get("position_y", entry.get("position", Vector3.ZERO).z),
	)
	if entry.has("position") and entry["position"] is Vector3:
		pos = entry["position"]
	var overrides: Dictionary = entry.get("overrides", {})
	# 标记实体属于哪个刷新组（用于死亡时触发重生）
	if not overrides.has("meta"):
		overrides["meta"] = {}
	overrides["meta"]["spawn_group_id"] = group_id

	var entity: GameEntity = EngineAPI.spawn_entity(def_id, pos, overrides)
	if entity:
		_group_entities[group_id].append(entity.runtime_id)
	return entity

func _on_entity_killed(data: Dictionary) -> void:
	var entity = data.get("entity")
	if entity == null or not (entity is GameEntity):
		return
	var ge: GameEntity = entity as GameEntity
	var group_id: String = ge.meta.get("spawn_group_id", "")
	if group_id == "":
		return
	# 启动重生计时器
	var group: Dictionary = _spawn_groups.get(group_id, {})
	if group.is_empty() or not group.get("enabled", true):
		return
	var respawn_time: float = group.get("respawn_time", 30.0)
	if respawn_time <= 0:
		return  # respawn_time <= 0 表示不重生
	# 找到对应的 entry（通过 def_id 匹配）
	var entries: Array = group.get("entries", [])
	var matched_entry: Dictionary = {}
	for entry in entries:
		if entry.get("def_id", "") == ge.def_id:
			matched_entry = entry
			break
	if matched_entry.is_empty():
		# 没找到精确匹配，用第一个 entry 作为 fallback
		if entries.size() > 0:
			matched_entry = entries[0]
		else:
			return
	var timer_id: int = _next_timer_id
	_next_timer_id += 1
	_respawn_timers[timer_id] = {
		"group_id": group_id,
		"remaining": respawn_time,
		"entry": matched_entry,
	}

func _on_entity_destroyed(data: Dictionary) -> void:
	var entity = data.get("entity")
	if entity == null or not (entity is GameEntity):
		return
	var ge: GameEntity = entity as GameEntity
	var group_id: String = ge.meta.get("spawn_group_id", "")
	if group_id != "" and _group_entities.has(group_id):
		_group_entities[group_id].erase(ge.runtime_id)

func _tick_timers(delta: float) -> void:
	var to_fire: Array = []
	for tid in _respawn_timers:
		_respawn_timers[tid]["remaining"] -= delta
		if _respawn_timers[tid]["remaining"] <= 0:
			to_fire.append(tid)
	for tid in to_fire:
		_fire_respawn(tid)

func _fire_respawn(timer_id: int) -> void:
	if not _respawn_timers.has(timer_id):
		return
	var timer: Dictionary = _respawn_timers[timer_id]
	var group_id: String = timer.get("group_id", "")
	var entry: Dictionary = timer.get("entry", {})
	_respawn_timers.erase(timer_id)

	var group: Dictionary = _spawn_groups.get(group_id, {})
	if group.is_empty() or not group.get("enabled", true):
		return
	# max_alive 检查
	var max_alive: int = group.get("max_alive", 0)
	if max_alive > 0 and _count_alive(group_id) >= max_alive:
		return
	# 条件检查
	if not _check_condition(group):
		return
	var entity: GameEntity = _spawn_entry(group_id, entry)
	if entity:
		EventBus.emit_event("entity_respawned", {
			"entity": entity, "group_id": group_id,
		})

func _count_alive(group_id: String) -> int:
	if not _group_entities.has(group_id):
		return 0
	var count := 0
	for rid in _group_entities[group_id]:
		var entity: Node3D = EngineAPI.get_entity_by_id(rid)
		if entity and is_instance_valid(entity) and entity is GameEntity and (entity as GameEntity).is_alive:
			count += 1
	return count

func _check_condition(group: Dictionary) -> bool:
	## 检查刷新条件（可扩展）
	var condition: Dictionary = group.get("condition", {})
	if condition.is_empty():
		return true  # 无条件
	var cond_type: String = condition.get("type", "")
	match cond_type:
		"game_state":
			return EngineAPI.get_game_state() == condition.get("state", "playing")
		"variable_check":
			var key: String = condition.get("key", "")
			var expected = condition.get("value")
			return EngineAPI.get_variable(key) == expected
		"min_alive":
			# 当存活数低于阈值时才刷新
			var group_id: String = group.get("group_id", "")
			var threshold: int = condition.get("threshold", 0)
			return _count_alive(group_id) < threshold
		_:
			return true
