## PlayerInputComponent - 玩家输入控制
## WASD 移动 + 自动攻击 + 警戒系统集成
extends Node

var _entity: Node3D = null
var _movement: Node = null
var _alert: Node = null
## 基础值（JSON 定义，注册到 StatSystem 作为白字基础）
var _base_cooldown: float = 0.3
var projectile_id: String = "arrow"
var _base_speed: float = 12.0
var _base_damage: float = 10.0
var _base_range: float = 5.0
var target_tag: String = "enemy"
var auto_attack_enabled: bool = true
var _shoot_timer: float = 0.0

## 实时战斗属性（从 StatSystem 读取，对标 TC UpdateAttackPowerAndDamage）
var projectile_damage: float:
	get:
		if _entity: return EngineAPI.get_total_stat(_entity, "atk")
		return _base_damage
var shoot_cooldown: float:
	get:
		if _entity:
			var aspd: float = EngineAPI.get_total_stat(_entity, "aspd")
			return maxf(_base_cooldown / maxf(1.0 + aspd, 0.1), 0.05)
		return _base_cooldown
var attack_range: float:
	get:
		if _entity: return EngineAPI.get_total_stat(_entity, "range")
		return _base_range
var projectile_speed: float:
	get: return _base_speed

## Blink（对标 TC 的 spell，但暂时保留在此）
var blink_distance: float = 5.0
var blink_mp_cost: float = 10.0
var blink_cooldown: float = 0.5
var _blink_cd_timer: float = 0.0
var _blink_pressed_last: bool = false

func setup(data: Dictionary) -> void:
	_base_cooldown = data.get("shoot_cooldown", 0.3)
	projectile_id = data.get("projectile_id", "arrow")
	_base_speed = data.get("projectile_speed", 12.0)
	_base_damage = data.get("projectile_damage", 10.0)
	_base_range = data.get("attack_range", 5.0)
	target_tag = data.get("target_tag", "enemy")
	auto_attack_enabled = data.get("auto_attack", true)
	blink_distance = data.get("blink_distance", 5.0)
	blink_mp_cost = data.get("blink_mp_cost", 10.0)
	blink_cooldown = data.get("blink_cooldown", 0.5)

func _on_attached(entity: Node3D) -> void:
	_entity = entity
	# 注册基础战斗属性到 StatSystem（白字基础值）
	EngineAPI.add_white_stat(entity, "atk", _base_damage)
	EngineAPI.add_white_stat(entity, "range", _base_range)
	EngineAPI.add_white_stat(entity, "aspd", 0.0)  # 基础攻速加成 0%

func _process(delta: float) -> void:
	if _entity == null or EngineAPI.get_game_state() != "playing":
		return
	_ensure_refs()
	# UnitFlags 检查：CC 状态阻止移动/攻击
	var flags_block_move: bool = _entity is GameEntity and (_entity as GameEntity).has_any_flag(UnitFlags.MOVEMENT_PREVENTING)
	var flags_block_attack: bool = _entity is GameEntity and (_entity as GameEntity).has_any_flag(UnitFlags.ATTACK_PREVENTING)
	if not flags_block_move:
		_handle_movement()
	elif _movement:
		_movement.velocity = Vector3.ZERO
	if not flags_block_attack and auto_attack_enabled:
		_handle_auto_attack(delta)
	# Blink cooldown tick
	if _blink_cd_timer > 0:
		_blink_cd_timer -= delta
	# T key blink (just-pressed detection)
	var blink_pressed := Input.is_key_pressed(KEY_T)
	if blink_pressed and not _blink_pressed_last and _blink_cd_timer <= 0 and not flags_block_move:
		_try_blink()
	_blink_pressed_last = blink_pressed

func _ensure_refs() -> void:
	if _movement == null and _entity.has_method("get_component"):
		_movement = _entity.get_component("movement")
	if _alert == null and _entity.has_method("get_component"):
		_alert = _entity.get_component("alert")

func _handle_movement() -> void:
	if _movement == null:
		return

	var dir := Vector3.ZERO
	# 3D: WASD 映射到 XZ 平面（前=Z-, 后=Z+, 左=X-, 右=X+）
	if Input.is_action_pressed("move_up") or Input.is_key_pressed(KEY_UP):
		dir.z -= 1
	if Input.is_action_pressed("move_down") or Input.is_key_pressed(KEY_DOWN):
		dir.z += 1
	if Input.is_action_pressed("move_left") or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_action_pressed("move_right") or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1

	if dir != Vector3.ZERO:
		# 手动移动：重置警戒计数
		if _alert and _alert.has_method("reset_approach_count"):
			_alert.reset_approach_count()
		dir = dir.normalized()
		_movement.velocity = dir * _movement.current_speed
	else:
		# 没有手动输入，检查警戒自动靠近
		if _alert and _alert.has_method("is_approaching") and _alert.is_approaching():
			var alert_dir: Vector3 = _alert.get_approach_direction()
			if alert_dir != Vector3.ZERO:
				_movement.velocity = alert_dir * _movement.current_speed
			else:
				_movement.velocity = Vector3.ZERO
		else:
			_movement.velocity = Vector3.ZERO

func _handle_auto_attack(delta: float) -> void:
	_shoot_timer += delta
	if _shoot_timer < shoot_cooldown:
		return
	var target := _find_nearest_enemy()
	if target == null:
		return
	_shoot_timer = 0.0
	var direction := _entity.global_position.direction_to(target.global_position)
	# 面向攻击目标
	var face_dir := target.global_position - _entity.global_position
	face_dir.y = 0
	if face_dir.length_squared() > 0.001:
		_entity.rotation.y = atan2(face_dir.x, face_dir.z)
	# 触发攻击动画
	var vis: Node = _entity.get_component("visual") if _entity.has_method("get_component") else null
	if vis and vis.has_method("play_attack"):
		vis.play_attack()
	EventBus.emit_event("player_shoot", {
		"shooter": _entity,
		"position": _entity.global_position,
		"direction": direction,
		"projectile_id": projectile_id,
		"speed": projectile_speed,
		"damage": projectile_damage,
	})

func _find_nearest_enemy() -> Node3D:
	var enemies: Array = EngineAPI.find_entities_in_area(
		_entity.global_position, attack_range, target_tag
	)
	if enemies.is_empty():
		return null
	var closest: Node3D = null
	var closest_dist := INF
	for e in enemies:
		var d := _entity.global_position.distance_squared_to(e.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = e
	return closest

func _try_blink() -> void:
	if _entity == null or not is_instance_valid(_entity):
		return
	var health: Node = _entity.get_component("health") if _entity.has_method("get_component") else null
	if health == null or not health.has_method("use_mana"):
		return
	if not health.use_mana(blink_mp_cost):
		return  # Not enough mana

	# Get blink direction toward mouse cursor
	var cam: Node = EngineAPI.get_system("camera")
	if cam == null or not cam.has_method("get_world_mouse_position"):
		return
	var mouse_pos: Vector3 = cam.call("get_world_mouse_position")
	var direction := mouse_pos - _entity.global_position
	direction.y = 0
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	direction = direction.normalized()

	var target := _entity.global_position + direction * blink_distance
	_entity.global_position = target
	_blink_cd_timer = blink_cooldown

	# VFX feedback
	var vfx: Node = EngineAPI.get_system("vfx")
	if vfx and vfx.has_method("spawn_vfx"):
		vfx.call("spawn_vfx", "shockwave", _entity.global_position, {"radius": 2.0})
