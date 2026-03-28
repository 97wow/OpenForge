## MovementComponent - 通用移动
## 支持速度控制和速度修改器（减速/加速 buff）
extends Node

var base_speed: float = 0.0
var current_speed: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.RIGHT

var _speed_modifiers: Dictionary = {}  # modifier_id -> factor
var _entity: Node2D = null

func setup(data: Dictionary) -> void:
	base_speed = data.get("speed", 0.0)
	current_speed = base_speed

func _on_attached(entity: Node2D) -> void:
	_entity = entity

func _process(delta: float) -> void:
	if _entity == null or velocity == Vector2.ZERO:
		return
	if EngineAPI.get_game_state() != "playing":
		return
	_entity.position += velocity * delta
	if velocity.length_squared() > 0:
		facing_direction = velocity.normalized()

func add_speed_modifier(modifier_id: String, factor: float) -> void:
	_speed_modifiers[modifier_id] = factor
	_recalculate_speed()

func remove_speed_modifier(modifier_id: String) -> void:
	_speed_modifiers.erase(modifier_id)
	_recalculate_speed()

func _recalculate_speed() -> void:
	var final_factor := 1.0
	for factor in _speed_modifiers.values():
		final_factor *= factor
	current_speed = base_speed * final_factor

func set_velocity_toward(target_pos: Vector2) -> void:
	if _entity == null:
		return
	var direction := (target_pos - _entity.global_position).normalized()
	velocity = direction * current_speed

func stop() -> void:
	velocity = Vector2.ZERO
