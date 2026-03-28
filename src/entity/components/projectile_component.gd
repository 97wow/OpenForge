## ProjectileComponent - 投射物行为
## 沿方向飞行，碰撞目标后造成伤害
## 支持穿透、分裂等扩展
extends Node

var _entity: Node2D = null
var direction: Vector2 = Vector2.RIGHT
var speed: float = 600.0
var damage: float = 10.0
var max_range: float = 800.0
var pierce_count: int = 0  # 0 = 不穿透
var target_tag: String = "enemy"
var source: Node2D = null
var hit_radius: float = 12.0
var damage_type: String = "physical"

var _distance_traveled: float = 0.0
var _pierced: int = 0
var _hit_entities: Array = []  # 已命中的实体（防重复）

func setup(data: Dictionary) -> void:
	direction = data.get("direction", Vector2.RIGHT)
	speed = data.get("speed", 600.0)
	damage = data.get("damage", 10.0)
	max_range = data.get("max_range", 800.0)
	pierce_count = data.get("pierce_count", 0)
	target_tag = data.get("target_tag", "enemy")
	source = data.get("source", null)
	hit_radius = data.get("hit_radius", 12.0)
	damage_type = data.get("damage_type", "physical")

var _trail: Line2D = null
var _trail_points: PackedVector2Array = []
const TRAIL_LENGTH := 8

func _on_attached(entity: Node2D) -> void:
	_entity = entity
	_entity.rotation = direction.angle()
	# 创建拖尾
	_trail = Line2D.new()
	_trail.width = 2.0
	_trail.z_index = -1
	# 根据伤害类型设置拖尾颜色
	var trail_color := Color(1, 1, 0.7, 0.5)
	match damage_type:
		"fire": trail_color = Color(1, 0.5, 0.15, 0.5)
		"frost", "ice": trail_color = Color(0.4, 0.8, 1, 0.5)
		"nature", "poison": trail_color = Color(0.3, 0.9, 0.3, 0.5)
		"shadow": trail_color = Color(0.6, 0.3, 0.9, 0.5)
		"holy": trail_color = Color(1, 0.9, 0.4, 0.5)
	_trail.default_color = trail_color
	var gradient := Gradient.new()
	gradient.set_color(0, Color(trail_color.r, trail_color.g, trail_color.b, 0))
	gradient.set_color(1, trail_color)
	_trail.gradient = gradient
	# 拖尾不跟随实体旋转，挂到父节点的父节点
	entity.add_child(_trail)
	_trail.top_level = true

func _process(delta: float) -> void:
	if _entity == null or EngineAPI.get_game_state() != "playing":
		return

	var move := direction * speed * delta
	_entity.position += move
	_distance_traveled += move.length()

	# 更新拖尾
	if _trail and is_instance_valid(_trail):
		_trail_points.append(_entity.global_position)
		if _trail_points.size() > TRAIL_LENGTH:
			_trail_points = _trail_points.slice(_trail_points.size() - TRAIL_LENGTH)
		_trail.points = _trail_points

	# 超出射程销毁
	if _distance_traveled >= max_range:
		EngineAPI.destroy_entity(_entity)
		return

	# 碰撞检测
	_check_hits()

func _check_hits() -> void:
	var targets: Array = EngineAPI.find_entities_in_area(
		_entity.global_position, hit_radius, target_tag
	)
	for target in targets:
		if target in _hit_entities:
			continue
		_hit_entities.append(target)

		# 造成伤害（含伤害类型）
		var health: Node = EngineAPI.get_component(target, "health")
		if health and health.has_method("take_damage"):
			var dt: int = health.parse_damage_type(damage_type) if health.has_method("parse_damage_type") else 0
			health.call("take_damage", damage, source, dt)

		EventBus.emit_event("projectile_hit", {
			"projectile": _entity,
			"target": target,
			"damage": damage,
			"damage_type": damage_type,
			"source": source,
		})

		# 穿透逻辑
		if _pierced >= pierce_count:
			EngineAPI.destroy_entity(_entity)
			return
		_pierced += 1
