## ProjectileComponent - 投射物行为
## 沿方向飞行，碰撞目标后造成伤害
## 支持穿透、分裂等扩展
extends Node

var _entity: Node3D = null
var direction: Vector3 = Vector3.RIGHT
var speed: float = 6.0
var damage: float = 10.0
var max_range: float = 8.0
var pierce_count: int = 0  # 0 = 不穿透
var target_tag: String = "enemy"
var source: Node3D = null
var hit_radius: float = 0.12
var damage_type: String = "physical"
var ability_name: String = ""  # 技能来源名（显示在伤害数字上）
var splash_radius: float = 0.0  # >0 时命中后对周围敌人造成溅射伤害
var splash_damage_pct: float = 0.5  # 溅射伤害 = 主伤害 × 此百分比

var _distance_traveled: float = 0.0
var _pierced: int = 0
var _hit_entities: Array = []  # 已命中的实体（防重复）

func setup(data: Dictionary) -> void:
	direction = data.get("direction", Vector3.RIGHT)
	speed = data.get("speed", 6.0)
	damage = data.get("damage", 10.0)
	max_range = data.get("max_range", 8.0)
	pierce_count = data.get("pierce_count", 0)
	target_tag = data.get("target_tag", "enemy")
	source = data.get("source", null)
	hit_radius = data.get("hit_radius", 0.12)
	damage_type = data.get("damage_type", "physical")
	ability_name = data.get("ability_name", "")
	splash_radius = data.get("splash_radius", 0.0)
	splash_damage_pct = data.get("splash_damage_pct", 0.5)

func _on_attached(entity: Node3D) -> void:
	_entity = entity
	# 延迟到进入场景树后再设置朝向（避免 not_in_tree 错误）
	if direction != Vector3.ZERO:
		if entity.is_inside_tree():
			entity.look_at(entity.global_position + direction, Vector3.UP)
		else:
			entity.ready.connect(func() -> void:
				if is_instance_valid(entity) and direction != Vector3.ZERO:
					entity.look_at(entity.global_position + direction, Vector3.UP)
			, CONNECT_ONE_SHOT)

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
	# 优先使用 faction 感知查询（source 存活时）
	var targets: Array = []
	if source and is_instance_valid(source) and source is GameEntity:
		targets = EngineAPI.find_hostiles_in_area(source, _entity.global_position, hit_radius)
	else:
		targets = EngineAPI.find_entities_in_area(_entity.global_position, hit_radius, target_tag)

	for target in targets:
		if target in _hit_entities:
			continue
		if target == source or target == _entity:
			continue

		_hit_entities.append(target)

		# 造成伤害
		var health: Node = EngineAPI.get_component(target, "health")
		if health and health.has_method("take_damage"):
			var dt: int = health.parse_damage_type(damage_type) if health.has_method("parse_damage_type") else 0
			var old_show: bool = health.show_damage_numbers
			health.show_damage_numbers = false
			health.call("take_damage", damage, source, dt, ability_name if ability_name != "" else damage_type)
			health.show_damage_numbers = old_show

		EventBus.emit_event("projectile_hit", {
			"projectile": _entity,
			"target": target,
			"damage": damage,
			"damage_type": damage_type,
			"source": source,
		})

		# AOE 溅射：命中后对周围敌人也造成伤害
		if splash_radius > 0 and is_instance_valid(target):
			var splash_dmg: float = damage * splash_damage_pct
			var splash_targets: Array = []
			if source and is_instance_valid(source) and source is GameEntity:
				splash_targets = EngineAPI.find_hostiles_in_area(source, (target as Node3D).global_position, splash_radius)
			else:
				splash_targets = EngineAPI.find_entities_in_area((target as Node3D).global_position, splash_radius, target_tag)
			for st in splash_targets:
				if st == target or st in _hit_entities:
					continue
				var sh: Node = EngineAPI.get_component(st, "health")
				if sh and sh.has_method("take_damage"):
					var sdt: int = sh.parse_damage_type(damage_type) if sh.has_method("parse_damage_type") else 0
					sh.call("take_damage", splash_dmg, source, sdt, "splash")

		# 穿透逻辑
		if _pierced >= pierce_count:
			EngineAPI.destroy_entity(_entity)
			return
		_pierced += 1
		return  # 每帧最多命中一个目标
