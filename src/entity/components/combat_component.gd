## CombatComponent - 通用战斗
## 攻击目标筛选通过 tag 控制，不硬编码"塔打敌人"
extends Node

var damage: float = 10.0
var attack_speed: float = 1.0  # 次/秒
var attack_range: float = 150.0
var attack_type: String = "single"  # single, aoe, chain
var target_filter_tag: String = ""  # 攻击哪些 tag 的实体
var targeting_strategy: String = "closest"  # closest, farthest, weakest, strongest
var gold_reward: int = 0
var damage_type: String = "physical"  # physical/frost/fire/nature/shadow/holy

var aoe_radius: float = 64.0
var chain_count: int = 3
var chain_range: float = 100.0
var chain_decay: float = 0.7
var on_hit_effects: Array = []

var _attack_timer: float = 0.0
var _entity: Node2D = null

func setup(data: Dictionary) -> void:
	damage = data.get("damage", 10.0)
	attack_speed = data.get("attack_speed", 1.0)
	attack_range = data.get("range", 150.0)
	attack_type = data.get("attack_type", "single")
	target_filter_tag = data.get("target_filter_tag", "")
	targeting_strategy = data.get("targeting", "closest")
	gold_reward = data.get("gold_reward", 0)
	damage_type = data.get("damage_type", "physical")
	aoe_radius = data.get("aoe_radius", 64.0)
	chain_count = data.get("chain_count", 3)
	chain_range = data.get("chain_range", 100.0)
	chain_decay = data.get("chain_decay", 0.7)
	on_hit_effects = data.get("on_hit_effects", [])

func _on_attached(entity: Node2D) -> void:
	_entity = entity

func _process(delta: float) -> void:
	if _entity == null or target_filter_tag == "":
		return
	if EngineAPI.get_game_state() != "playing":
		return
	if attack_speed <= 0:
		return

	_attack_timer += delta
	if _attack_timer >= 1.0 / attack_speed:
		_attack_timer = 0.0
		_try_attack()

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

func _find_target() -> Node2D:
	var candidates := EngineAPI.find_entities_in_area(
		_entity.global_position, attack_range, target_filter_tag
	)
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

func _deal_damage(target: Node2D, amount: float) -> void:
	var health: Node = target.get_component("health") if target.has_method("get_component") else null
	if health and health.has_method("take_damage"):
		var dt: int = health.parse_damage_type(damage_type) if health.has_method("parse_damage_type") else 0
		health.call("take_damage", amount, _entity, dt)
	# 应用命中效果
	for effect in on_hit_effects:
		if effect is Dictionary:
			EngineAPI.apply_buff(
				target,
				effect.get("buff_id", ""),
				effect.get("duration", 2.0),
				effect
			)

func _attack_aoe() -> void:
	var targets := EngineAPI.find_entities_in_area(
		_entity.global_position, attack_range, target_filter_tag
	)
	for target in targets:
		_deal_damage(target, damage)

func _attack_chain(first: Node2D) -> void:
	var hit: Array[Node2D] = [first]
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

func _find_next_chain(from: Node2D, exclude: Array[Node2D]) -> Node2D:
	var candidates := EngineAPI.find_entities_in_area(
		from.global_position, chain_range, target_filter_tag
	)
	var closest: Node2D = null
	var closest_dist := INF
	for c in candidates:
		if c in exclude:
			continue
		var dist := from.global_position.distance_squared_to(c.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = c
	return closest

func _get_closest(candidates: Array) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for c in candidates:
		var dist := _entity.global_position.distance_squared_to(c.global_position)
		if dist < best_dist:
			best_dist = dist
			best = c
	return best

func _get_farthest(candidates: Array) -> Node2D:
	var best: Node2D = null
	var best_dist := -1.0
	for c in candidates:
		var dist := _entity.global_position.distance_squared_to(c.global_position)
		if dist > best_dist:
			best_dist = dist
			best = c
	return best

func _get_weakest(candidates: Array) -> Node2D:
	var best: Node2D = null
	var best_hp := INF
	for c in candidates:
		var health = c.get_component("health") if c.has_method("get_component") else null
		if health:
			var hp: float = health.current_hp
			if hp < best_hp:
				best_hp = hp
				best = c
	return best

func _get_strongest(candidates: Array) -> Node2D:
	var best: Node2D = null
	var best_hp := -1.0
	for c in candidates:
		var health = c.get_component("health") if c.has_method("get_component") else null
		if health:
			var hp: float = health.current_hp
			if hp > best_hp:
				best_hp = hp
				best = c
	return best
