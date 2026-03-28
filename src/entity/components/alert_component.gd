## AlertComponent - 警戒范围系统（框架层）
## 当目标进入警戒范围，实体自动靠近到攻击范围
## 最多自动靠近 N 次，防止被风筝/无限吸引
## 手动移动重置计数器
extends Node

var alert_range: float = 500.0
var attack_range: float = 350.0
var target_tag: String = "enemy"
var max_auto_approaches: int = 2
var alert_enabled: bool = true

var _entity: Node2D = null
var _movement: Node = null
var _approach_count: int = 0
var _current_target: Node2D = null
var _is_approaching: bool = false

func setup(data: Dictionary) -> void:
	alert_range = data.get("alert_range", 500.0)
	attack_range = data.get("attack_range", 350.0)
	target_tag = data.get("target_tag", "enemy")
	max_auto_approaches = data.get("max_auto_approaches", 2)
	alert_enabled = data.get("alert_enabled", true)

func _on_attached(entity: Node2D) -> void:
	_entity = entity

func set_alert_enabled(enabled: bool) -> void:
	alert_enabled = enabled
	if not enabled:
		_is_approaching = false
		_current_target = null

func reset_approach_count() -> void:
	_approach_count = 0
	_is_approaching = false
	_current_target = null

func _process(_delta: float) -> void:
	if _entity == null or not alert_enabled:
		return
	if EngineAPI.get_game_state() != "playing":
		return
	if _movement == null and _entity.has_method("get_component"):
		_movement = _entity.get_component("movement")
	if _movement == null:
		return

	# 已经在靠近中
	if _is_approaching and _current_target and is_instance_valid(_current_target):
		var dist := _entity.global_position.distance_to(_current_target.global_position)
		if dist <= attack_range:
			# 到达攻击范围，停止靠近
			_is_approaching = false
			_current_target = null
			return
		# 继续移动（不改变 velocity，由 player_input 控制优先）
		return

	# 检查是否有敌人进入警戒范围
	if _approach_count >= max_auto_approaches:
		return

	var nearest := _find_alert_target()
	if nearest == null:
		return

	var dist := _entity.global_position.distance_to(nearest.global_position)
	# 在警戒范围内但不在攻击范围内 → 自动靠近
	if dist <= alert_range and dist > attack_range:
		_current_target = nearest
		_is_approaching = true
		_approach_count += 1
		EventBus.emit_event("alert_triggered", {
			"entity": _entity,
			"target": nearest,
			"approach_count": _approach_count,
		})

func get_approach_direction() -> Vector2:
	## 返回靠近方向，供 player_input 使用
	if not _is_approaching or _current_target == null or not is_instance_valid(_current_target):
		return Vector2.ZERO
	return _entity.global_position.direction_to(_current_target.global_position)

func is_approaching() -> bool:
	return _is_approaching

func _find_alert_target() -> Node2D:
	var enemies: Array = EngineAPI.find_entities_in_area(
		_entity.global_position, alert_range, target_tag
	)
	if enemies.is_empty():
		return null
	var closest: Node2D = null
	var closest_dist := INF
	for e in enemies:
		var d := _entity.global_position.distance_squared_to(e.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = e
	return closest
