## AlertComponent - 警戒范围系统（框架层）
## 状态机：IDLE → WAITING → APPROACHING → IN_COMBAT → WAIT_RETURN → RETURNING → IDLE
extends Node

enum State { IDLE, WAIT_APPROACH, APPROACHING, IN_COMBAT, WAIT_RETURN, RETURNING }

var alert_range: float = 500.0
var attack_range: float = 350.0
var target_tag: String = "enemy"
var max_auto_approaches: int = 2
var alert_enabled: bool = true

var _entity: Node2D = null
var _movement: Node = null
var _state: State = State.IDLE
var _approach_count: int = 0
var _current_target: Node2D = null
var _home_position: Vector2 = Vector2.ZERO
var _has_home: bool = false
var _delay_timer: float = 0.0
var _delay_target: float = 0.0

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
		_state = State.IDLE
		_current_target = null

func reset_approach_count() -> void:
	## WASD 手动移动时调用：重置一切
	_approach_count = 0
	_state = State.IDLE
	_current_target = null
	_has_home = false

func _process(delta: float) -> void:
	if _entity == null or not alert_enabled:
		return
	if EngineAPI.get_game_state() != "playing":
		return
	if _movement == null and _entity.has_method("get_component"):
		_movement = _entity.get_component("movement")
	if _movement == null:
		return

	match _state:
		State.IDLE:
			_process_idle()
		State.WAIT_APPROACH:
			_process_delay(delta, State.APPROACHING)
		State.APPROACHING:
			_process_approaching()
		State.IN_COMBAT:
			_process_in_combat()
		State.WAIT_RETURN:
			_process_delay(delta, State.RETURNING)
		State.RETURNING:
			_process_returning()

func _process_idle() -> void:
	if _approach_count >= max_auto_approaches:
		return
	var nearest := _find_nearest_in_alert_range()
	if nearest == null:
		return
	var dist := _entity.global_position.distance_to(nearest.global_position)
	if dist > attack_range:
		# 敌人在警戒范围内但不在攻击范围 → 准备靠近
		_home_position = _entity.global_position
		_has_home = true
		_current_target = nearest
		_approach_count += 1
		_start_delay(State.WAIT_APPROACH)

func _process_approaching() -> void:
	if _current_target == null or not is_instance_valid(_current_target):
		_state = State.IN_COMBAT  # 目标消失，进入战斗等待状态
		return
	var dist := _entity.global_position.distance_to(_current_target.global_position)
	if dist <= attack_range:
		_state = State.IN_COMBAT
		_current_target = null

func _process_in_combat() -> void:
	# 战斗中：等待警戒范围内所有敌人消失
	var enemies: Array = EngineAPI.find_entities_in_area(
		_entity.global_position, alert_range, target_tag
	)
	if enemies.is_empty() and _has_home:
		_start_delay(State.WAIT_RETURN)

func _process_returning() -> void:
	if not _has_home:
		_state = State.IDLE
		return
	var dist := _entity.global_position.distance_to(_home_position)
	if dist <= 10.0:
		_state = State.IDLE
		_has_home = false
		return
	# 返回途中如果又发现敌人，停止返回进入战斗
	var enemies: Array = EngineAPI.find_entities_in_area(
		_entity.global_position, alert_range, target_tag
	)
	if not enemies.is_empty():
		_state = State.IN_COMBAT

func _process_delay(delta: float, next_state: State) -> void:
	_delay_timer += delta
	if _delay_timer >= _delay_target:
		_state = next_state

func _start_delay(wait_state: State) -> void:
	_state = wait_state
	_delay_timer = 0.0
	_delay_target = randf_range(0.5, 1.0)

# === 给 PlayerInput 读取的接口 ===

func get_approach_direction() -> Vector2:
	match _state:
		State.APPROACHING:
			if _current_target and is_instance_valid(_current_target):
				return _entity.global_position.direction_to(_current_target.global_position)
		State.RETURNING:
			if _has_home:
				return _entity.global_position.direction_to(_home_position)
	return Vector2.ZERO

func is_approaching() -> bool:
	return _state == State.APPROACHING or _state == State.RETURNING

func _find_nearest_in_alert_range() -> Node2D:
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
