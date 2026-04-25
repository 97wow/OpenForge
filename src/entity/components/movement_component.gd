## MovementComponent - 通用移动
## 支持速度控制和速度修改器（减速/加速 buff）
extends Node

var base_speed: float = 0.0
var current_speed: float = 0.0
var velocity: Vector3 = Vector3.ZERO
var facing_direction: Vector3 = Vector3.FORWARD  # (0, 0, -1)

var _speed_modifiers: Dictionary = {}  # modifier_id -> factor
var _entity: Node3D = null

func setup(data: Dictionary) -> void:
	base_speed = data.get("speed", 0.0)
	current_speed = base_speed

func _on_attached(entity: Node3D) -> void:
	_entity = entity
	set_process(false)
	# 注册 base_speed 到 StatSystem
	EngineAPI.add_white_stat(entity, "move_speed", 0.0)  # base 由 speed modifier 管理
	EventBus.connect_event("stat_changed", _on_stat_changed)

func _on_stat_changed(data: Dictionary) -> void:
	if data.get("entity") == _entity and data.get("stat") == "move_speed":
		_recalculate_speed()

var separation_radius: float = 0.8  # 分离半径（约半个角色宽度）
var separation_strength: float = 2.0
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _sep_timer: float = 0.0
const SEP_INTERVAL := 0.2  # 分离力每0.2秒计算一次（而非每帧）
@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _cached_sep: Vector3 = Vector3.ZERO

func _process(_delta: float) -> void:
	pass  # 由 EntitySystem 中心化更新（位移 + 分离力都在那里处理）

func _calculate_separation() -> Vector3:
	if not (_entity is GameEntity):
		return Vector3.ZERO
	var my_faction: String = (_entity as GameEntity).faction
	var push := Vector3.ZERO
	var count := 0
	var my_pos: Vector3 = _entity.global_position
	var parent: Node = _entity.get_parent()
	if parent == null:
		return Vector3.ZERO
	var radius_sq: float = separation_radius * separation_radius
	for child in parent.get_children():
		if child == _entity or not (child is GameEntity):
			continue
		# 只跟同阵营的实体做分离（敌人和敌人分离，不跟玩家分离）
		if (child as GameEntity).faction != my_faction:
			continue
		var diff: Vector3 = my_pos - (child as Node3D).global_position
		diff.y = 0.0  # 地面分离，忽略 Y 轴
		var dist_sq: float = diff.length_squared()
		if dist_sq < 1.0:
			push += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
			count += 1
		elif dist_sq < radius_sq:
			var dist: float = sqrt(dist_sq)
			push += diff / dist * (1.0 - dist / separation_radius)
			count += 1
		if count >= 4:
			break
	if count > 0:
		return push / count
	return Vector3.ZERO

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
	# 从 StatSystem 读取 move_speed 加成（对标 TC Unit::UpdateSpeed）
	var speed_bonus: float = 0.0
	if _entity and is_instance_valid(_entity):
		speed_bonus = EngineAPI.get_total_stat(_entity, "move_speed")
	current_speed = (base_speed + speed_bonus) * final_factor

func set_velocity_toward(target_pos: Vector3) -> void:
	if _entity == null:
		return
	var direction := (target_pos - _entity.global_position).normalized()
	velocity = direction * current_speed

func stop() -> void:
	velocity = Vector3.ZERO
