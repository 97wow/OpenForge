## EconomySystem - 经济系统
## 管理金币、收入、消费
class_name EconomySystem
extends Node

var gold: int = 0
var income_per_tick: int = 0
var _income_interval: float = 10.0  # 每 10 秒结算一次收入
var _income_timer: float = 0.0

func init_economy(starting_gold: int, base_income: int = 0) -> void:
	gold = starting_gold
	income_per_tick = base_income
	_income_timer = 0.0
	EventBus.gold_changed.emit(gold, 0)

func can_afford(cost: int) -> bool:
	return gold >= cost

func spend(amount: int) -> bool:
	if amount <= 0:
		return false
	if gold < amount:
		return false
	gold -= amount
	EventBus.gold_changed.emit(gold, -amount)
	return true

func earn(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	EventBus.gold_changed.emit(gold, amount)

func add_income(amount: int) -> void:
	income_per_tick += amount

func _process(delta: float) -> void:
	if GameEngine.state != GameEngine.GameState.PLAYING:
		return
	if income_per_tick <= 0:
		return
	_income_timer += delta
	if _income_timer >= _income_interval:
		_income_timer -= _income_interval
		earn(income_per_tick)
		EventBus.income_tick.emit(income_per_tick)
