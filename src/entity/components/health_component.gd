## HealthComponent - 生命值管理
## 通用组件：任何需要血量的实体都可以使用
extends Node

var max_hp: float = 100.0
var current_hp: float = 100.0
var armor: float = 0.0
var _entity: Node2D = null

func setup(data: Dictionary) -> void:
	max_hp = data.get("max_hp", 100.0)
	current_hp = max_hp
	armor = data.get("armor", 0.0)

func _on_attached(entity: Node2D) -> void:
	_entity = entity

func take_damage(amount: float, source: Node2D = null) -> float:
	var effective := maxf(amount - armor, 1.0)
	var old_hp := current_hp
	current_hp = maxf(current_hp - effective, 0.0)

	EventBus.emit_event("entity_damaged", {
		"entity": _entity,
		"amount": effective,
		"source": source,
		"old_hp": old_hp,
		"new_hp": current_hp,
	})

	if current_hp <= 0.0:
		_die()
	return effective

func heal(amount: float, source: Node2D = null) -> float:
	var old_hp := current_hp
	current_hp = minf(current_hp + amount, max_hp)
	var actual := current_hp - old_hp

	if actual > 0:
		EventBus.emit_event("entity_healed", {
			"entity": _entity,
			"amount": actual,
			"source": source,
		})
	return actual

func is_alive() -> bool:
	return current_hp > 0.0

func get_hp_ratio() -> float:
	return current_hp / max_hp if max_hp > 0 else 0.0

func _die() -> void:
	if _entity and is_instance_valid(_entity):
		EngineAPI.destroy_entity(_entity)
