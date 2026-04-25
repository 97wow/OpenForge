## CombatComponent - 通用战斗
## 攻击目标筛选通过 tag 控制，不硬编码"塔打敌人"
extends Node

var damage: float = 10.0
var attack_speed: float = 1.0  # 次/秒
var attack_range: float = 1.5
var attack_type: String = "single"  # single, aoe, chain
var target_filter_tag: String = ""  # 攻击哪些 tag 的实体
var targeting_strategy: String = "closest"  # closest, farthest, weakest, strongest
var gold_reward: int = 0
var damage_type: String = "physical"  # physical/frost/fire/nature/shadow/holy

var aoe_radius: float = 0.64
var chain_count: int = 3
var chain_range: float = 1.0
var chain_decay: float = 0.7
var on_hit_effects: Array = []

@warning_ignore("UNUSED_PRIVATE_CLASS_VARIABLE")
var _attack_timer: float = 0.0
var _entity: Node3D = null

## 视觉弹道缓存（全局共享，减少 GPU 对象创建）
static var _cached_bullet_mesh: SphereMesh = null
static var _cached_bullet_mats: Dictionary = {}  # color_html -> StandardMaterial3D

static func _get_bullet_mesh() -> SphereMesh:
	if _cached_bullet_mesh == null:
		_cached_bullet_mesh = SphereMesh.new()
		_cached_bullet_mesh.radius = 0.15
		_cached_bullet_mesh.height = 0.3
	return _cached_bullet_mesh

static func _get_bullet_mat(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _cached_bullet_mats.has(key):
		return _cached_bullet_mats[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	_cached_bullet_mats[key] = mat
	return mat

func setup(data: Dictionary) -> void:
	damage = data.get("damage", 10.0)
	attack_speed = data.get("attack_speed", 1.0)
	attack_range = data.get("range", 1.5)
	attack_type = data.get("attack_type", "single")
	target_filter_tag = data.get("target_filter_tag", "")
	targeting_strategy = data.get("targeting", "closest")
	gold_reward = data.get("gold_reward", 0)
	damage_type = data.get("damage_type", "physical")
	aoe_radius = data.get("aoe_radius", 0.64)
	chain_count = data.get("chain_count", 3)
	chain_range = data.get("chain_range", 1.0)
	chain_decay = data.get("chain_decay", 0.7)
	on_hit_effects = data.get("on_hit_effects", [])

func _on_attached(entity: Node3D) -> void:
	_entity = entity
	# 延迟启动 process（避免刚 spawn 就开始搜索）
	set_process(false)
	if entity.is_inside_tree():
		_deferred_enable_process()
	else:
		entity.ready.connect(_deferred_enable_process, CONNECT_ONE_SHOT)

func _deferred_enable_process() -> void:
	set_process(true)

func _process(_delta: float) -> void:
	pass  # 由 EntitySystem 中心化更新

func _try_attack() -> void:
	var target := _find_target()
	if target == null:
		return
	match attack_type:
		"single":
			_deal_damage(target, damage)
		"aoe":
			_attack_aoe()
		"chain":
			_attack_chain(target)

func _find_target() -> Node3D:
	# COMBAT 状态：优先使用 ThreatManager 的仇恨目标（保持与 AI 移动一致）
	if _entity is GameEntity:
		var ai_state: int = (_entity as GameEntity).meta.get("ai_state", 0)
		if ai_state == 1:  # COMBAT
			var victim: Node3D = EngineAPI.get_threat_victim(_entity)
			if victim and _entity.global_position.distance_to(victim.global_position) <= attack_range:
				return victim
	# Fallback：faction 系统查找攻击范围内的敌对目标
	var candidates: Array = []
	if _entity is GameEntity:
		candidates = EngineAPI.find_hostiles_in_area(_entity, _entity.global_position, attack_range)
	else:
		candidates = EngineAPI.find_entities_in_area(_entity.global_position, attack_range, target_filter_tag)
	if candidates.is_empty():
		return null

	match targeting_strategy:
		"closest":
			return _get_closest(candidates)
		"farthest":
			return _get_farthest(candidates)
		"weakest":
			return _get_weakest(candidates)
		"strongest":
			return _get_strongest(candidates)
		_:
			return _get_closest(candidates)

func _deal_damage(target: Node3D, amount: float) -> void:
	# 面向攻击目标
	if _entity and is_instance_valid(_entity) and is_instance_valid(target):
		var dir := target.global_position - _entity.global_position
		dir.y = 0
		if dir.length_squared() > 0.001:
			_entity.rotation.y = atan2(dir.x, dir.z)
	# 触发攻击动画
	if _entity and is_instance_valid(_entity):
		var vis: Node = _entity.get_component("visual") if _entity.has_method("get_component") else null
		if vis and vis.has_method("play_attack"):
			vis.play_attack()
	# 远程攻击：显示弹道
	if attack_range >= 0.8 and _entity and is_instance_valid(_entity) and _entity.is_inside_tree() and is_instance_valid(target) and target.is_inside_tree():
		_spawn_attack_projectile(_entity.global_position, target)

	var health: Node = target.get_component("health") if target.has_method("get_component") else null
	if health and health.has_method("take_damage"):
		var dt: int = health.parse_damage_type(damage_type) if health.has_method("parse_damage_type") else 0
		var ab_name: String = _entity.def_id + "_atk" if _entity is GameEntity else "melee"
		health.call("take_damage", amount, _entity, dt, ab_name)
	# 应用命中效果
	for effect in on_hit_effects:
		if effect is Dictionary:
			EngineAPI.apply_buff(
				target,
				effect.get("buff_id", ""),
				effect.get("duration", 2.0),
				effect
			)

func _spawn_attack_projectile(from: Vector3, target: Node3D) -> void:
	## 纯视觉弹道（不造成伤害，仅用于攻击可见性）
	if not _entity.is_inside_tree():
		return
	var scene_root: Node = _entity.get_tree().current_scene
	if scene_root == null:
		return

	var bullet := MeshInstance3D.new()
	# 弹道颜色根据伤害类型
	var bullet_color := Color(0.9, 0.9, 0.5, 0.9)
	match damage_type:
		"fire": bullet_color = Color(1, 0.4, 0.1, 0.9)
		"frost", "ice": bullet_color = Color(0.3, 0.7, 1, 0.9)
		"nature", "poison": bullet_color = Color(0.3, 0.9, 0.3, 0.9)
		"shadow": bullet_color = Color(0.6, 0.2, 0.9, 0.9)
		"holy": bullet_color = Color(1, 0.9, 0.4, 0.9)
	# 复用缓存的 mesh 和 material（减少 GPU 对象创建）
	bullet.mesh = _get_bullet_mesh()
	bullet.set_surface_override_material(0, _get_bullet_mat(bullet_color))
	# 先加入场景树，再设 global_position（避免 not_in_tree 错误）
	scene_root.add_child(bullet)
	bullet.global_position = from + Vector3(0, 0.5, 0)

	# 飞向目标的 tween
	var target_pos := target.global_position + Vector3(0, 0.5, 0)
	var dist := from.distance_to(target_pos)
	var duration := clampf(dist / 6.0, 0.05, 0.4)
	var tw := bullet.create_tween()
	tw.tween_property(bullet, "global_position", target_pos, duration)
	tw.tween_callback(bullet.queue_free)

func _attack_aoe() -> void:
	var targets: Array = []
	if _entity is GameEntity:
		targets = EngineAPI.find_hostiles_in_area(_entity, _entity.global_position, attack_range)
	else:
		targets = EngineAPI.find_entities_in_area(_entity.global_position, attack_range, target_filter_tag)
	for target in targets:
		_deal_damage(target, damage)

func _attack_chain(first: Node3D) -> void:
	var hit: Array[Node3D] = [first]
	var current := first
	var current_damage := damage
	_deal_damage(current, current_damage)

	for i in range(chain_count - 1):
		current_damage *= chain_decay
		var next := _find_next_chain(current, hit)
		if next == null:
			break
		_deal_damage(next, current_damage)
		hit.append(next)
		current = next

func _find_next_chain(from: Node3D, exclude: Array[Node3D]) -> Node3D:
	var candidates: Array = []
	if _entity is GameEntity:
		candidates = EngineAPI.find_hostiles_in_area(_entity, from.global_position, chain_range)
	else:
		candidates = EngineAPI.find_entities_in_area(from.global_position, chain_range, target_filter_tag)
	var closest: Node3D = null
	var closest_dist := INF
	for c in candidates:
		if c in exclude:
			continue
		var dist := from.global_position.distance_squared_to(c.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = c
	return closest

func _get_closest(candidates: Array) -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for c in candidates:
		var dist := _entity.global_position.distance_squared_to(c.global_position)
		if dist < best_dist:
			best_dist = dist
			best = c
	return best

func _get_farthest(candidates: Array) -> Node3D:
	var best: Node3D = null
	var best_dist := -1.0
	for c in candidates:
		var dist := _entity.global_position.distance_squared_to(c.global_position)
		if dist > best_dist:
			best_dist = dist
			best = c
	return best

func _get_weakest(candidates: Array) -> Node3D:
	var best: Node3D = null
	var best_hp := INF
	for c in candidates:
		var health = c.get_component("health") if c.has_method("get_component") else null
		if health:
			var hp: float = health.current_hp
			if hp < best_hp:
				best_hp = hp
				best = c
	return best

func _get_strongest(candidates: Array) -> Node3D:
	var best: Node3D = null
	var best_hp := -1.0
	for c in candidates:
		var health = c.get_component("health") if c.has_method("get_component") else null
		if health:
			var hp: float = health.current_hp
			if hp > best_hp:
				best_hp = hp
				best = c
	return best
