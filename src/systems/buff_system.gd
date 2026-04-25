## BuffSystem - 通用 Buff/Debuff 管理
## 效果通过 StatSystem 绿字属性实现，不硬编码任何特定效果
class_name BuffSystem
extends Node

# entity_id -> { buff_id -> BuffInstance }
var _active_buffs: Dictionary = {}

func _ready() -> void:
	EngineAPI.register_system("buff", self)

# === 应用/移除 ===

func apply_buff(target: Node3D, buff_id: String, duration: float, data: Dictionary = {}) -> void:
	if not is_instance_valid(target) or not target is GameEntity:
		return
	var entity := target as GameEntity
	var eid: int = entity.runtime_id

	# 查找 buff 定义
	var buff_def: Dictionary = DataRegistry.get_def("buffs", buff_id)
	var merged: Dictionary = buff_def.duplicate()
	merged.merge(data, true)
	merged["remaining"] = duration
	merged["duration"] = duration

	if not _active_buffs.has(eid):
		_active_buffs[eid] = {}

	var entity_buffs: Dictionary = _active_buffs[eid]
	var stack_mode: String = merged.get("stack_mode", "refresh")

	if entity_buffs.has(buff_id):
		match stack_mode:
			"refresh":
				entity_buffs[buff_id]["remaining"] = duration
			"stack":
				var max_stacks: int = merged.get("max_stacks", 5)
				var current: int = entity_buffs[buff_id].get("stacks", 1)
				if current < max_stacks:
					entity_buffs[buff_id]["stacks"] = current + 1
				entity_buffs[buff_id]["remaining"] = duration
			"independent":
				pass
		return

	merged["stacks"] = 1
	merged["applied_mods"] = []  # [{stat, type, value}] — 用于精确移除
	merged["entity_ref"] = entity  # 保存实体引用，移除时使用
	entity_buffs[buff_id] = merged

	# 应用 stat modifiers
	_apply_stat_modifiers(entity, buff_id, merged)

	EventBus.emit_event("buff_applied", {"entity": target, "buff_id": buff_id})

func remove_buff(target: Node3D, buff_id: String) -> void:
	if not is_instance_valid(target) or not target is GameEntity:
		return
	var eid: int = (target as GameEntity).runtime_id
	if not _active_buffs.has(eid) or not _active_buffs[eid].has(buff_id):
		return

	var buff: Dictionary = _active_buffs[eid][buff_id]
	_remove_stat_modifiers(buff)
	_active_buffs[eid].erase(buff_id)

	EventBus.emit_event("buff_removed", {"entity": target, "buff_id": buff_id})

func has_buff(target: Node3D, buff_id: String) -> bool:
	if not target is GameEntity:
		return false
	var eid: int = (target as GameEntity).runtime_id
	return _active_buffs.has(eid) and _active_buffs[eid].has(buff_id)

# === 更新 ===

func _process(delta: float) -> void:
	if EngineAPI.get_game_state() != "playing":
		return
	var to_remove: Array = []
	for eid in _active_buffs:
		var entity_buffs: Dictionary = _active_buffs[eid]
		for buff_id in entity_buffs:
			var buff: Dictionary = entity_buffs[buff_id]
			buff["remaining"] -= delta
			if buff["remaining"] <= 0:
				to_remove.append({"eid": eid, "buff_id": buff_id})

	for entry in to_remove:
		var eid: int = entry["eid"]
		var buff_id: String = entry["buff_id"]
		if _active_buffs.has(eid) and _active_buffs[eid].has(buff_id):
			var buff: Dictionary = _active_buffs[eid][buff_id]
			_remove_stat_modifiers(buff)
			_active_buffs[eid].erase(buff_id)
			var entity := EngineAPI.get_entity_by_id(eid)
			if entity:
				EventBus.emit_event("buff_removed", {"entity": entity, "buff_id": buff_id})

# === 内部 ===

func _apply_stat_modifiers(entity: GameEntity, _buff_id: String, buff: Dictionary) -> void:
	var stat_mods: Array = buff.get("stat_modifiers", [])
	for mod in stat_mods:
		if not mod is Dictionary:
			continue
		var stat_name: String = mod.get("stat", "")
		var mod_type: String = mod.get("type", "flat")
		var mod_value: float = mod.get("value", 0.0)
		if stat_name == "" or mod_value == 0.0:
			continue
		if mod_type == "percent":
			EngineAPI.add_green_percent(entity, stat_name, mod_value)
		else:
			EngineAPI.add_green_stat(entity, stat_name, mod_value)
		buff["applied_mods"].append({"stat": stat_name, "type": mod_type, "value": mod_value})

func _remove_stat_modifiers(buff: Dictionary) -> void:
	var entity = buff.get("entity_ref")
	if entity == null or not is_instance_valid(entity):
		return
	for mod in buff.get("applied_mods", []):
		var stat_name: String = mod.get("stat", "")
		var mod_type: String = mod.get("type", "flat")
		var mod_value: float = mod.get("value", 0.0)
		if mod_type == "percent":
			EngineAPI.remove_green_percent(entity, stat_name, mod_value)
		else:
			EngineAPI.remove_green_stat(entity, stat_name, mod_value)
	buff["applied_mods"].clear()

func clear_entity_buffs(entity: Node3D) -> void:
	if not entity is GameEntity:
		return
	var eid: int = (entity as GameEntity).runtime_id
	if _active_buffs.has(eid):
		for buff_id in _active_buffs[eid].keys():
			var buff: Dictionary = _active_buffs[eid][buff_id]
			_remove_stat_modifiers(buff)
		_active_buffs.erase(eid)
