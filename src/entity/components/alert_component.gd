## AlertComponent - 警戒范围系统（框架层）
## 当目标进入警戒范围，实体自动靠近到攻击范围
## 攻击结束后自动返回原位（首次被触发时的位置）
## 最多自动靠近 N 次，防止被风筝/无限吸引
## 手动移动重置计数器和原位
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
var _is_returning: bool = false
var _home_position: Vector2 = Vector2.ZERO  # 首次警戒触发时的位置
var _has_home: bool = false

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
		_is_returning = false
		_current_target = null

func reset_approach_count() -> void:
	_approach_count = 0
	_is_approaching = false
	_is_returning = false
	_current_target = null
	_has_home = false

func _process(_delta: float) -> void:
	if _entity == null or not alert_enabled:
		return
	if EngineAPI.get_game_state() != "playing":
		return
	if _movement == null and _entity.has_method("get_component"):
		_movement = _entity.get_component("movement")
	if _movement == null:
		return

	# 返回原位中
	if _is_returning:
		var dist_home := _entity.global_position.distance_to(_home_position)
		if dist_home <= 10.0:
			_is_returning = false
		return

	# 靠近中 → 检查是否到达攻击范围或目标消失
	if _is_approaching:
		if _current_target == null or not is_instance_valid(_current_target):
			# 目标消失，返回原位
			_is_approaching = false
			_start_return()
			return
		var dist := _entity.global_position.distance_to(_current_target.global_position)
		if dist <= attack_range:
			_is_approaching = false
			_current_target = null
			# 不立即返回，等没有攻击目标时再返回
		return

	# 当前没有在靠近/返回，检查是否需要返回原位
	if _has_home and not _is_approaching:
		# 检查攻击范围内是否还有敌人
		var enemies_in_range: Array = EngineAPI.find_entities_in_area(
			_entity.global_position, attack_range, target_tag
		)
		if enemies_in_range.is_empty():
			_start_return()
			return

	# 检查是否有敌人进入警戒范围
	if _approach_count >= max_auto_approaches:
		return

	var nearest := _find_alert_target()
	if nearest == null:
		return

	var dist := _entity.global_position.distance_to(nearest.global_position)
	if dist <= alert_range and dist > attack_range:
		# 记录首次触发位置
		if not _has_home:
			_home_position = _entity.global_position
			_has_home = true
		_current_target = nearest
		_is_approaching = true
		_approach_count += 1
		EventBus.emit_event("alert_triggered", {
			"entity": _entity,
			"target": nearest,
			"approach_count": _approach_count,
		})

func _start_return() -> void:
	if _has_home:
		_is_returning = true

func get_approach_direction() -> Vector2:
	if _is_returning and _has_home:
		return _entity.global_position.direction_to(_home_position)
	if not _is_approaching or _current_target == null or not is_instance_valid(_current_target):
		return Vector2.ZERO
	return _entity.global_position.direction_to(_current_target.global_position)

func is_approaching() -> bool:
	return _is_approaching or _is_returning

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
