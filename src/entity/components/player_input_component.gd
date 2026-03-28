## PlayerInputComponent - 玩家输入控制
## WASD 移动 + 自动攻击 + 警戒系统集成
extends Node

var _entity: Node2D = null
var _movement: Node = null
var _alert: Node = null
var shoot_cooldown: float = 0.3
var projectile_id: String = "arrow"
var projectile_speed: float = 600.0
var projectile_damage: float = 10.0
var attack_range: float = 350.0
var target_tag: String = "enemy"
var _shoot_timer: float = 0.0

func setup(data: Dictionary) -> void:
	shoot_cooldown = data.get("shoot_cooldown", 0.3)
	projectile_id = data.get("projectile_id", "arrow")
	projectile_speed = data.get("projectile_speed", 600.0)
	projectile_damage = data.get("projectile_damage", 10.0)
	attack_range = data.get("attack_range", 350.0)
	target_tag = data.get("target_tag", "enemy")

func _on_attached(entity: Node2D) -> void:
	_entity = entity

func _process(delta: float) -> void:
	if _entity == null or EngineAPI.get_game_state() != "playing":
		return
	_ensure_refs()
	_handle_movement()
	_handle_auto_attack(delta)

func _ensure_refs() -> void:
	if _movement == null and _entity.has_method("get_component"):
		_movement = _entity.get_component("movement")
	if _alert == null and _entity.has_method("get_component"):
		_alert = _entity.get_component("alert")

func _handle_movement() -> void:
	if _movement == null:
		return

	var dir := Vector2.ZERO
	if Input.is_action_pressed("move_up"):
		dir.y -= 1
	if Input.is_action_pressed("move_down"):
		dir.y += 1
	if Input.is_action_pressed("move_left"):
		dir.x -= 1
	if Input.is_action_pressed("move_right"):
		dir.x += 1

	if dir != Vector2.ZERO:
		# 手动移动：重置警戒计数
		if _alert and _alert.has_method("reset_approach_count"):
			_alert.reset_approach_count()
		dir = dir.normalized()
		_movement.velocity = dir * _movement.current_speed
	else:
		# 没有手动输入，检查警戒自动靠近
		if _alert and _alert.has_method("is_approaching") and _alert.is_approaching():
			var alert_dir: Vector2 = _alert.get_approach_direction()
			if alert_dir != Vector2.ZERO:
				_movement.velocity = alert_dir * _movement.current_speed
			else:
				_movement.velocity = Vector2.ZERO
		else:
			_movement.velocity = Vector2.ZERO

func _handle_auto_attack(delta: float) -> void:
	_shoot_timer += delta
	if _shoot_timer < shoot_cooldown:
		return
	var target := _find_nearest_enemy()
	if target == null:
		return
	_shoot_timer = 0.0
	var direction := _entity.global_position.direction_to(target.global_position)
	EventBus.emit_event("player_shoot", {
		"shooter": _entity,
		"position": _entity.global_position,
		"direction": direction,
		"projectile_id": projectile_id,
		"speed": projectile_speed,
		"damage": projectile_damage,
	})

func _find_nearest_enemy() -> Node2D:
	var enemies: Array = EngineAPI.find_entities_in_area(
		_entity.global_position, attack_range, target_tag
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
