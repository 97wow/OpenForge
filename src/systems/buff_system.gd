## BuffSystem - Buff/效果管理
## 统一管理所有增益/减益效果（减速、灼烧、加速等）
class_name BuffSystem
extends Node

# buff_id -> { target -> { remaining_time, stacks, data } }
var _active_buffs: Dictionary = {}

func apply_buff(target: Node2D, buff_id: String, duration: float, data: Dictionary = {}) -> void:
	if not is_instance_valid(target):
		return
	var buff_def := DataManager.get_affix(buff_id)
	var buff_data := buff_def.duplicate()
	buff_data.merge(data, true)  # 允许运行时覆盖
	buff_data["remaining"] = duration
	buff_data["duration"] = duration

	if not _active_buffs.has(buff_id):
		_active_buffs[buff_id] = {}

	var targets: Dictionary = _active_buffs[buff_id]
	var target_id := target.get_instance_id()

	var stack_mode: String = buff_data.get("stack_mode", "refresh")
	if targets.has(target_id):
		match stack_mode:
			"refresh":
				targets[target_id]["remaining"] = duration
			"stack":
				var max_stacks: int = buff_data.get("max_stacks", 5)
				var current: int = targets[target_id].get("stacks", 1)
				if current < max_stacks:
					targets[target_id]["stacks"] = current + 1
				targets[target_id]["remaining"] = duration
			"independent":
				pass  # 不覆盖，让旧的自然过期
	else:
		buff_data["stacks"] = 1
		targets[target_id] = buff_data
		_apply_effect(target, buff_id, buff_data)
		EventBus.buff_applied.emit(target, buff_id)

func remove_buff(target: Node2D, buff_id: String) -> void:
	if not _active_buffs.has(buff_id):
		return
	var target_id := target.get_instance_id()
	var targets: Dictionary = _active_buffs[buff_id]
	if targets.has(target_id):
		_remove_effect(target, buff_id, targets[target_id])
		targets.erase(target_id)
		EventBus.buff_removed.emit(target, buff_id)

func has_buff(target: Node2D, buff_id: String) -> bool:
	if not _active_buffs.has(buff_id):
		return false
	return _active_buffs[buff_id].has(target.get_instance_id())

func _process(delta: float) -> void:
	if GameEngine.state != GameEngine.GameState.PLAYING:
		return

	var to_remove: Array = []
	for buff_id in _active_buffs:
		var targets: Dictionary = _active_buffs[buff_id]
		for target_id in targets:
			var buff: Dictionary = targets[target_id]
			buff["remaining"] -= delta

			# 持续伤害/治疗 tick
			_tick_effect(target_id, buff_id, buff, delta)

			if buff["remaining"] <= 0:
				to_remove.append({"buff_id": buff_id, "target_id": target_id})

	for entry in to_remove:
		var targets: Dictionary = _active_buffs[entry["buff_id"]]
		if targets.has(entry["target_id"]):
			var instance := instance_from_id(entry["target_id"])
			if is_instance_valid(instance) and instance is Node2D:
				_remove_effect(instance as Node2D, entry["buff_id"], targets[entry["target_id"]])
				EventBus.buff_removed.emit(instance as Node2D, entry["buff_id"])
			targets.erase(entry["target_id"])

func _apply_effect(target: Node2D, _buff_id: String, data: Dictionary) -> void:
	var effect_type: String = data.get("effect", "")
	match effect_type:
		"slow":
			if target.has_method("apply_speed_modifier"):
				target.apply_speed_modifier(data.get("value", 0.5))
		"dot":
			pass  # DoT 在 _tick_effect 中处理

func _remove_effect(target: Node2D, _buff_id: String, data: Dictionary) -> void:
	var effect_type: String = data.get("effect", "")
	match effect_type:
		"slow":
			if target.has_method("remove_speed_modifier"):
				target.remove_speed_modifier(data.get("value", 0.5))

func _tick_effect(target_id: int, _buff_id: String, data: Dictionary, delta: float) -> void:
	var effect_type: String = data.get("effect", "")
	if effect_type != "dot":
		return
	var instance := instance_from_id(target_id)
	if not is_instance_valid(instance) or not instance is Node2D:
		return
	var dps: float = data.get("dps", 0.0) * data.get("stacks", 1)
	if instance.has_method("take_damage"):
		(instance as Node2D).call("take_damage", dps * delta)
