## HealthComponent - 生命值管理 + 伤害类型 + 浮动伤害数字
## 伤害类型参考魔兽世界：Physical/Frost/Fire/Nature/Shadow/Holy
class_name HealthComponent
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
	DamageType.FROST:    Color(0.31, 0.78, 1.0),        # 冰蓝
	DamageType.FIRE:     Color(1.0, 0.49, 0.16),        # 火焰橙
	DamageType.NATURE:   Color(0.30, 0.87, 0.30),       # 自然绿
	DamageType.SHADOW:   Color(0.64, 0.21, 0.93),       # 暗影紫
	DamageType.HOLY:     Color(1.0, 0.90, 0.35),        # 神圣金
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
var _entity: Node3D = null

## Mana system
var max_mp: float = 100.0
var current_mp: float = 100.0
var mp_regen: float = 2.0  # per second

func setup(data: Dictionary) -> void:
	max_hp = data.get("max_hp", 100.0)
	current_hp = max_hp
	armor = data.get("armor", 0.0)
	magic_resist = data.get("magic_resist", 0.0)
	show_damage_numbers = data.get("show_damage_numbers", true)
	max_mp = data.get("max_mp", 100.0)
	current_mp = max_mp
	mp_regen = data.get("mp_regen", 2.0)

func _on_attached(entity: Node3D) -> void:
	_entity = entity

func take_damage(amount: float, source: Node3D = null, damage_type: int = DamageType.PHYSICAL, ability: String = "", is_proc: bool = false) -> float:
	## 统一伤害入口（委托给 DamagePipeline，向后兼容所有现有调用）
	var result: Dictionary = DamagePipeline.deal_damage({
		"attacker": source,
		"target": _entity,
		"base_amount": amount,
		"school": damage_type,
		"ability": ability,
		"is_proc": is_proc,
		"flags": DamagePipeline.IS_PROC if is_proc else 0,
	})
	return result.get("effective_damage", 0.0)

func apply_hp_change(amount: float) -> float:
	## 纯 HP 扣减（DamagePipeline 专用，不触发事件/不做减免）
	var old_hp := current_hp
	current_hp = maxf(current_hp - amount, 0.0)
	var actual := old_hp - current_hp
	if actual > 0 and current_hp > 0 and _entity and is_instance_valid(_entity):
		var vis: Node = _entity.get_component("visual") if _entity.has_method("get_component") else null
		if vis and vis.has_method("play_hit"):
			vis.play_hit()
	_notify_visual()
	return actual

func heal(amount: float, source: Node3D = null, ability: String = "") -> float:
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
			"ability": ability,
		})
		_notify_visual()
	return actual

func is_alive() -> bool:
	return current_hp > 0.0

func get_hp_ratio() -> float:
	return current_hp / max_hp if max_hp > 0 else 0.0

## --- Mana methods ---

func use_mana(amount: float) -> bool:
	if current_mp < amount:
		return false
	current_mp = maxf(current_mp - amount, 0.0)
	return true

func restore_mana(amount: float) -> float:
	var old := current_mp
	current_mp = minf(current_mp + amount, max_mp)
	return current_mp - old

func get_mp_ratio() -> float:
	return current_mp / max_mp if max_mp > 0 else 0.0

func _notify_visual() -> void:
	if _entity and is_instance_valid(_entity) and _entity.has_method("get_component"):
		var visual: Node = _entity.get_component("visual")
		if visual and visual.has_method("update_hp_bar"):
			visual.update_hp_bar()

func _die() -> void:
	## 备用死亡入口（主要走 DamagePipeline 的延迟死亡序列）
	if _entity and is_instance_valid(_entity):
		# 标记死亡状态（对标 TrinityCore Unit::setDeathState）
		if _entity is GameEntity:
			(_entity as GameEntity).is_alive = false
			(_entity as GameEntity).set_unit_flag(UnitFlags.IMMUNE_DAMAGE)
		# 委托给 DamagePipeline 的死亡序列（播放动画+淡出+销毁）
		DamagePipeline._start_death_sequence(_entity)

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

static var _i18n_cache: Node = null
## 全局伤害数字计数
static var _active_dmg_labels: int = 0
const MAX_DMG_LABELS: int = 60

static func _get_i18n() -> Node:
	if _i18n_cache == null or not is_instance_valid(_i18n_cache):
		_i18n_cache = Engine.get_main_loop().root.get_node_or_null("I18n") if Engine.get_main_loop() else null
	return _i18n_cache

static func can_spawn_label() -> bool:
	return _active_dmg_labels < MAX_DMG_LABELS

static func inc_label_count() -> void:
	_active_dmg_labels += 1

static func dec_label_count() -> void:
	_active_dmg_labels -= 1

func _spawn_damage_number(amount: float, damage_type: int = DamageType.PHYSICAL, ability: String = "") -> void:
	if _active_dmg_labels >= MAX_DMG_LABELS:
		return

	var text: String = ""
	if ability != "":
		var i18n_node: Node = _get_i18n()
		var ab_name: String = ""
		if i18n_node and i18n_node.has_method("t"):
			var ab_key := "ABILITY_" + ability.to_upper()
			ab_name = i18n_node.call("t", ab_key)
			if ab_name == ab_key:
				ab_name = ""
		if ab_name == "":
			ab_name = ability.replace("_", " ").capitalize()
		text = "%s %d" % [ab_name, int(amount)]
	else:
		text = str(int(amount))

	var color: Color = DAMAGE_COLORS.get(damage_type, Color.WHITE)
	var font_size := 32
	if amount >= 50:
		font_size = 48
	elif amount >= 25:
		font_size = 40

	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 20
	label.outline_size = 8
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.position = _entity.global_position + Vector3(randf_range(-0.3, 0.3), 2.0, randf_range(-0.2, 0.2))
	# 初始缩小，准备弹出
	label.scale = Vector3(0.5, 0.5, 0.5)

	var scene_root: Node = _entity.get_tree().current_scene if _entity.get_tree() else null
	if scene_root:
		scene_root.add_child(label)
	else:
		_entity.add_child(label)

	_active_dmg_labels += 1
	var tween := label.create_tween()
	# 阶段1：弹出放大（0.15秒）
	tween.tween_property(label, "scale", Vector3(1.4, 1.4, 1.4), 0.15).set_ease(Tween.EASE_OUT)
	# 阶段2：回弹恢复（0.2秒）
	tween.tween_property(label, "scale", Vector3(1.0, 1.0, 1.0), 0.2).set_ease(Tween.EASE_IN_OUT)
	# 阶段3：停留（0.3秒）
	tween.tween_interval(0.3)
	# 阶段4：上飘 + 渐隐（0.8秒）
	tween.tween_property(label, "position:y", label.position.y + 2.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(func() -> void:
		_active_dmg_labels -= 1
		label.queue_free()
	)

func _spawn_heal_number(amount: float) -> void:
	if _active_dmg_labels >= MAX_DMG_LABELS:
		return

	var label := Label3D.new()
	label.text = "+%d" % int(amount)
	label.font_size = 28
	label.modulate = Color(0.3, 1, 0.3)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 20
	label.position = _entity.global_position + Vector3(randf_range(-0.3, 0.3), 1.5, 0)

	var scene_root: Node = _entity.get_tree().current_scene if _entity.get_tree() else null
	if scene_root:
		scene_root.add_child(label)
	else:
		_entity.add_child(label)

	_active_dmg_labels += 1
	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y + 1.2, 0.45).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.4).set_delay(0.05)
	tween.tween_callback(func() -> void:
		_active_dmg_labels -= 1
		label.queue_free()
	)
