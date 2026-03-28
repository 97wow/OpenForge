## AIMoveToComponent - AI 移动到目标
## 让实体自动向指定目标或位置移动
## 到达攻击范围后停下并攻击
extends Node

var _entity: Node2D = null
var _movement: Node = null
var target_tag: String = ""  # 寻找哪个 tag 的实体作为目标
var target_entity: Node2D = null
var attack_range: float = 30.0  # 到达多近就停下
var _reached: bool = false

func setup(data: Dictionary) -> void:
	target_tag = data.get("target_tag", "")
	attack_range = data.get("attack_range", 30.0)

func _on_attached(entity: Node2D) -> void:
	_entity = entity

func _process(_delta: float) -> void:
	if _entity == null or EngineAPI.get_game_state() != "playing":
		return
	if _movement == null and _entity.has_method("get_component"):
		_movement = _entity.get_component("movement")
	if _movement == null:
		return

	# 寻找目标
	if target_entity == null or not is_instance_valid(target_entity):
		_reached = false
		target_entity = _find_target()
		if target_entity == null:
			_movement.velocity = Vector2.ZERO
			return

	# 移动到目标
	var dist := _entity.global_position.distance_to(target_entity.global_position)
	if dist <= attack_range:
		_movement.velocity = Vector2.ZERO
		if not _reached:
			_reached = true
			EventBus.emit_event("ai_reached_target", {
				"entity": _entity,
				"target": target_entity,
			})
	else:
		_reached = false
		var dir := _entity.global_position.direction_to(target_entity.global_position)
		_movement.velocity = dir * _movement.current_speed

func _find_target() -> Node2D:
	if target_tag == "":
		return null
	var candidates: Array = EngineAPI.find_entities_by_tag(target_tag)
	if candidates.is_empty():
		return null
	# 找最近的
	var closest: Node2D = null
	var closest_dist := INF
	for c in candidates:
		if not is_instance_valid(c):
			continue
		var d := _entity.global_position.distance_squared_to(c.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = c
	return closest
