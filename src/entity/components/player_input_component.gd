## PlayerInputComponent - 玩家输入控制
## WASD 移动 + 鼠标瞄准 + 左键射击
## 通用组件：任何需要玩家控制的实体都可以使用
extends Node

var _entity: Node2D = null
var _movement: Node = null  # MovementComponent reference
var shoot_cooldown: float = 0.3  # 射击间隔
var projectile_id: String = "arrow"  # 投射物实体 ID
var projectile_speed: float = 600.0
var projectile_damage: float = 10.0
var _shoot_timer: float = 0.0
var _can_shoot: bool = true

func setup(data: Dictionary) -> void:
	shoot_cooldown = data.get("shoot_cooldown", 0.3)
	projectile_id = data.get("projectile_id", "arrow")
	projectile_speed = data.get("projectile_speed", 600.0)
	projectile_damage = data.get("projectile_damage", 10.0)

func _on_attached(entity: Node2D) -> void:
	_entity = entity

func _process(delta: float) -> void:
	if _entity == null or EngineAPI.get_game_state() != "playing":
		return

	_handle_movement()
	_handle_shooting(delta)

func _handle_movement() -> void:
	if _movement == null and _entity.has_method("get_component"):
		_movement = _entity.get_component("movement")
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
		dir = dir.normalized()
		_movement.velocity = dir * _movement.current_speed
	else:
		_movement.velocity = Vector2.ZERO

func _handle_shooting(delta: float) -> void:
	if not _can_shoot:
		_shoot_timer += delta
		if _shoot_timer >= shoot_cooldown:
			_can_shoot = true
			_shoot_timer = 0.0

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _can_shoot:
		_shoot()
		_can_shoot = false
		_shoot_timer = 0.0

func _shoot() -> void:
	var mouse_pos := _entity.get_global_mouse_position()
	var direction := (_entity.global_position.direction_to(mouse_pos))

	EventBus.emit_event("player_shoot", {
		"shooter": _entity,
		"position": _entity.global_position,
		"direction": direction,
		"projectile_id": projectile_id,
		"speed": projectile_speed,
		"damage": projectile_damage,
	})
