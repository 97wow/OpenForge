## BaseTower - 防御塔基类
## 所有塔的行为都由数据驱动，不同塔通过不同数据实现差异
class_name BaseTower
extends Node2D

var tower_id: String = ""
var grid_pos: Vector2i = Vector2i.ZERO
var tower_data: Dictionary = {}
var level: int = 1

# 战斗属性（从 data 中加载）
var attack_damage: float = 10.0
var attack_speed: float = 1.0  # 攻击/秒
var attack_range: float = 150.0
var attack_type: String = "single"  # single, aoe, chain

var _attack_timer: float = 0.0
var _current_target: Node2D = null

@onready var range_area: Area2D = $RangeArea
@onready var sprite: Sprite2D = $Sprite2D
@onready var attack_timer_node: Timer = $AttackTimer

func setup(id: String, data: Dictionary, pos: Vector2i) -> void:
	tower_id = id
	tower_data = data
	grid_pos = pos
	_apply_data(data)

func _apply_data(data: Dictionary) -> void:
	attack_damage = data.get("damage", 10.0)
	attack_speed = data.get("attack_speed", 1.0)
	attack_range = data.get("range", 150.0)
	attack_type = data.get("attack_type", "single")

	# 设置攻击范围碰撞体
	if range_area:
		var shape := CircleShape2D.new()
		shape.radius = attack_range
		if range_area.get_child_count() > 0:
			var collision := range_area.get_child(0) as CollisionShape2D
			if collision:
				collision.shape = shape

func _process(delta: float) -> void:
	if GameEngine.state != GameEngine.GameState.PLAYING:
		return

	_attack_timer += delta
	if _attack_timer >= 1.0 / attack_speed:
		_attack_timer = 0.0
		_try_attack()

func _try_attack() -> void:
	_current_target = _find_target()
	if _current_target == null:
		return

	match attack_type:
		"single":
			_attack_single(_current_target)
		"aoe":
			_attack_aoe()
		"chain":
			_attack_chain(_current_target)

func _find_target() -> Node2D:
	var enemies := GameEngine.get_enemies_in_range(global_position, attack_range)
	if enemies.is_empty():
		return null
	# 默认策略：最近的敌人（后续可扩展为 first/last/strongest）
	var closest: Node2D = null
	var closest_dist := INF
	for enemy in enemies:
		var dist := global_position.distance_squared_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy
	return closest

func _attack_single(target: Node2D) -> void:
	if target.has_method("take_damage"):
		target.call("take_damage", attack_damage)
	# 应用附加效果
	var effects: Array = tower_data.get("on_hit_effects", [])
	for effect in effects:
		if effect is Dictionary:
			GameEngine.buff_system.apply_buff(
				target,
				effect.get("buff_id", ""),
				effect.get("duration", 2.0),
				effect
			)

func _attack_aoe() -> void:
	var aoe_radius: float = tower_data.get("aoe_radius", 64.0)
	var enemies := GameEngine.get_enemies_in_range(global_position, attack_range)
	for enemy in enemies:
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", attack_damage)

func _attack_chain(first_target: Node2D) -> void:
	var chain_count: int = tower_data.get("chain_count", 3)
	var chain_range: float = tower_data.get("chain_range", 100.0)
	var chain_decay: float = tower_data.get("chain_decay", 0.7)

	var hit_targets: Array[Node2D] = [first_target]
	var current := first_target
	var current_damage := attack_damage

	if current.has_method("take_damage"):
		current.call("take_damage", current_damage)

	for i in range(chain_count - 1):
		current_damage *= chain_decay
		var next := _find_chain_target(current, chain_range, hit_targets)
		if next == null:
			break
		if next.has_method("take_damage"):
			next.call("take_damage", current_damage)
		hit_targets.append(next)
		current = next

func _find_chain_target(from: Node2D, range_val: float, exclude: Array[Node2D]) -> Node2D:
	var enemies := GameEngine.get_enemies_in_range(from.global_position, range_val)
	var closest: Node2D = null
	var closest_dist := INF
	for enemy in enemies:
		if enemy in exclude:
			continue
		var dist := from.global_position.distance_squared_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = enemy
	return closest

func get_sell_value() -> int:
	var base_cost: int = tower_data.get("cost", 0)
	return int(base_cost * 0.7)

func get_upgrade_cost() -> int:
	var costs: Array = tower_data.get("upgrade_costs", [])
	if level - 1 < costs.size():
		return costs[level - 1]
	return -1  # 无法升级
