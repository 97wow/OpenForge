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

func _on_attached(entity: Node2D) -> void:
	_entity = entity
	# 旋转投射物朝向飞行方向
	_entity.rotation = direction.angle()

func _process(delta: float) -> void:
	if _entity == null or EngineAPI.get_game_state() != "playing":
		return

	var move := direction * speed * delta
	_entity.position += move
	_distance_traveled += move.length()

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
