## HealthComponent - 生命值管理 + 浮动伤害数字
extends Node

var max_hp: float = 100.0
var current_hp: float = 100.0
var armor: float = 0.0
var show_damage_numbers: bool = true
var _entity: Node2D = null

func setup(data: Dictionary) -> void:
	max_hp = data.get("max_hp", 100.0)
	current_hp = max_hp
	armor = data.get("armor", 0.0)
	show_damage_numbers = data.get("show_damage_numbers", true)

func _on_attached(entity: Node2D) -> void:
	_entity = entity

func take_damage(amount: float, source: Node2D = null) -> float:
	var effective := maxf(amount - armor, 1.0)
	var old_hp := current_hp
	current_hp = maxf(current_hp - effective, 0.0)

	if show_damage_numbers and _entity and is_instance_valid(_entity):
		_spawn_damage_number(effective)

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
		if show_damage_numbers and _entity and is_instance_valid(_entity):
			_spawn_heal_number(actual)
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

func _spawn_damage_number(amount: float) -> void:
	var label := Label.new()
	label.text = str(int(amount))
	label.add_theme_font_size_override("font_size", 14)
	# 高伤害用红色，普通用白色
	if amount >= 20:
		label.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
		label.add_theme_font_size_override("font_size", 18)
	else:
		label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	label.position = Vector2(randf_range(-10, 10), -20)
	label.z_index = 50
	_entity.add_child(label)
	# 向上漂浮并淡出
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(label.queue_free)

func _spawn_heal_number(amount: float) -> void:
	var label := Label.new()
	label.text = "+%d" % int(amount)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
	label.position = Vector2(randf_range(-10, 10), -20)
	label.z_index = 50
	_entity.add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 30, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(label.queue_free)
