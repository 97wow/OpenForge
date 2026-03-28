## HealthComponent - 生命值管理 + 伤害类型 + 浮动伤害数字
## 伤害类型参考魔兽世界：Physical/Frost/Fire/Nature/Shadow/Holy
extends Node

## 伤害类型枚举（框架层定义，GamePack 使用）
enum DamageType {
	PHYSICAL,  # 物理（白色）
	FROST,     # 冰霜（蓝色）
	FIRE,      # 火焰（橙色）
	NATURE,    # 自然（绿色）
	SHADOW,    # 暗影（紫色）
	HOLY,      # 神圣（黄色）
}

## 伤害类型 → 颜色映射（魔兽世界配色）
const DAMAGE_COLORS: Dictionary = {
	DamageType.PHYSICAL: Color(1.0, 1.0, 1.0),         # 白色
	DamageType.FROST:    Color(0.31, 0.78, 1.0),        # #4FC7FF 冰蓝
	DamageType.FIRE:     Color(1.0, 0.49, 0.16),        # #FF7D28 火焰橙
	DamageType.NATURE:   Color(0.30, 0.87, 0.30),       # #4DDE4D 自然绿
	DamageType.SHADOW:   Color(0.64, 0.21, 0.93),       # #A336ED 暗影紫
	DamageType.HOLY:     Color(1.0, 0.90, 0.35),        # #FFE659 神圣金
}

## 伤害类型 → 名称键（用于 i18n）
const DAMAGE_TYPE_KEYS: Dictionary = {
	DamageType.PHYSICAL: "DMG_PHYSICAL",
	DamageType.FROST:    "DMG_FROST",
	DamageType.FIRE:     "DMG_FIRE",
	DamageType.NATURE:   "DMG_NATURE",
	DamageType.SHADOW:   "DMG_SHADOW",
	DamageType.HOLY:     "DMG_HOLY",
}

var max_hp: float = 100.0
var current_hp: float = 100.0
var armor: float = 0.0
var magic_resist: float = 0.0  # 魔法抗性（减少非物理伤害）
var show_damage_numbers: bool = true
var _entity: Node2D = null

func setup(data: Dictionary) -> void:
	max_hp = data.get("max_hp", 100.0)
	current_hp = max_hp
	armor = data.get("armor", 0.0)
	magic_resist = data.get("magic_resist", 0.0)
	show_damage_numbers = data.get("show_damage_numbers", true)

func _on_attached(entity: Node2D) -> void:
	_entity = entity

func take_damage(amount: float, source: Node2D = null, damage_type: int = DamageType.PHYSICAL) -> float:
	## 造成伤害，支持伤害类型
	## damage_type: DamageType 枚举值
	var reduction := 0.0
	if damage_type == DamageType.PHYSICAL:
		reduction = armor
	else:
		# 非物理伤害：护甲减免较少（1/3），加魔抗
		reduction = armor * 0.33 + magic_resist

	var effective := maxf(amount - reduction, 1.0)
	var old_hp := current_hp
	current_hp = maxf(current_hp - effective, 0.0)

	if show_damage_numbers and _entity and is_instance_valid(_entity):
		_spawn_damage_number(effective, damage_type)

	EventBus.emit_event("entity_damaged", {
		"entity": _entity,
		"amount": effective,
		"source": source,
		"damage_type": damage_type,
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

## 获取伤害类型颜色（静态工具方法，GamePack 可调用）
static func get_damage_color(damage_type: int) -> Color:
	return DAMAGE_COLORS.get(damage_type, Color.WHITE)

## 根据字符串获取伤害类型枚举
static func parse_damage_type(type_str: String) -> int:
	match type_str.to_lower():
		"physical": return DamageType.PHYSICAL
		"frost", "ice": return DamageType.FROST
		"fire": return DamageType.FIRE
		"nature", "poison": return DamageType.NATURE
		"shadow", "dark": return DamageType.SHADOW
		"holy", "light": return DamageType.HOLY
		_: return DamageType.PHYSICAL

func _spawn_damage_number(amount: float, damage_type: int = DamageType.PHYSICAL) -> void:
	var label := Label.new()
	label.text = str(int(amount))
	var base_size := 14
	var color: Color = DAMAGE_COLORS.get(damage_type, Color.WHITE)

	# 高伤害加大字号
	if amount >= 25:
		base_size = 20
	elif amount >= 15:
		base_size = 16

	label.add_theme_font_size_override("font_size", base_size)
	label.add_theme_color_override("font_color", color)
	label.position = Vector2(randf_range(-12, 12), -20)
	label.z_index = 50
	_entity.add_child(label)

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
