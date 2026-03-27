## BaseEnemy - 敌人基类
## 沿路径移动，受到伤害后死亡并奖励金币
class_name BaseEnemy
extends PathFollow2D

var enemy_id: String = ""
var enemy_data: Dictionary = {}

# 属性
var max_hp: float = 100.0
var current_hp: float = 100.0
var move_speed: float = 80.0
var base_speed: float = 80.0
var armor: float = 0.0
var gold_reward: int = 10
var lives_cost: int = 1

# 速度修改器（用于减速 buff）
var _speed_modifiers: Array[float] = []

@onready var sprite: Sprite2D = $Sprite2D
@onready var hp_bar: ProgressBar = $HPBar

func setup(id: String, data: Dictionary, path: Path2D) -> void:
	enemy_id = id
	enemy_data = data
	max_hp = data.get("hp", 100.0)
	current_hp = max_hp
	base_speed = data.get("speed", 80.0)
	move_speed = base_speed
	armor = data.get("armor", 0.0)
	gold_reward = data.get("gold_reward", 10)
	lives_cost = data.get("lives_cost", 1)

	# 将自己挂到 Path2D 下
	reparent(path)
	progress = 0.0
	_update_hp_bar()

func _process(delta: float) -> void:
	if GameEngine.state != GameEngine.GameState.PLAYING:
		return

	progress += move_speed * delta

	if progress_ratio >= 1.0:
		_reached_end()

func take_damage(amount: float) -> void:
	var effective_damage := maxf(amount - armor, 1.0)
	current_hp -= effective_damage
	_update_hp_bar()

	if current_hp <= 0:
		_die()

func heal(amount: float) -> void:
	current_hp = minf(current_hp + amount, max_hp)
	_update_hp_bar()

func apply_speed_modifier(factor: float) -> void:
	_speed_modifiers.append(factor)
	_recalculate_speed()

func remove_speed_modifier(factor: float) -> void:
	var idx := _speed_modifiers.find(factor)
	if idx >= 0:
		_speed_modifiers.remove_at(idx)
	_recalculate_speed()

func _recalculate_speed() -> void:
	var final_modifier := 1.0
	for mod in _speed_modifiers:
		final_modifier *= mod  # 减速 buff 传入 0.5 则速度减半
	move_speed = base_speed * final_modifier

func _die() -> void:
	GameEngine.economy_system.earn(gold_reward)
	EventBus.enemy_killed.emit(self, null)
	queue_free()

func _reached_end() -> void:
	EventBus.enemy_reached_end.emit(self)
	EventBus.lives_changed.emit(-lives_cost, -lives_cost)
	queue_free()

func _update_hp_bar() -> void:
	if hp_bar:
		hp_bar.value = current_hp / max_hp * 100.0
		hp_bar.visible = current_hp < max_hp

func get_hp_ratio() -> float:
	return current_hp / max_hp if max_hp > 0 else 0.0
