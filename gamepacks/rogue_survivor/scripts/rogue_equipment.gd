## RogueEquipment — 装备升级系统
## 三件装备：炮塔（自动进化）、武器（金币升级）、盾牌（武器+10解锁）
## 每10级换名换皮+属性跳升+锻造词条三选一
extends RefCounted

var _gm = null

# === 装备状态 ===
var turret_level: int = 0
var turret_grade: String = ""  # "", "B", "A", "S", "SS"
var weapon_level: int = -1  # -1 = 未解锁
var shield_level: int = -1  # -1 = 未解锁
var weapon_unlocked: bool = false
var shield_unlocked: bool = false

# 锻造词条（永久加成）
var forge_bonuses: Array[Dictionary] = []  # [{stat, value}, ...]

# 选词条 UI
var _forge_ui: Control = null

# === 炮塔进化配置 ===
const TURRET_GRADES := {
	"B": {"kills": 500, "atk": 100, "all_stat": 15},
	"A": {"kills": 1500, "atk": 500, "all_stat": 20},
	"S": {"kills": 2500, "atk": 1000, "all_stat": 25},
	"SS": {"kills": 3500, "atk": 2000, "all_stat": 30},
}
const TURRET_GRADE_ORDER := ["B", "A", "S", "SS"]

# === 武器段位配置 ===
const WEAPON_TIERS := [
	{"name_key": "IRON_SWORD", "base_atk": 50, "atk_per_lv": 10, "aspd": 0.20, "cost": 500},
	{"name_key": "FROSTMOURNE", "base_atk": 200, "atk_per_lv": 20, "aspd": 0.30, "cost": 1000},
	{"name_key": "FLAME_SWORD", "base_atk": 400, "atk_per_lv": 20, "aspd": 0.50, "cost": 1500},
	{"name_key": "TRIPLE_SPEAR", "base_atk": 600, "atk_per_lv": 20, "aspd": 0.75, "cost": 2000},
	{"name_key": "SEA_TRIDENT", "base_atk": 800, "atk_per_lv": 20, "aspd": 1.00, "cost": 3000},
	{"name_key": "DARK_HALBERD", "base_atk": 1000, "atk_per_lv": 20, "aspd": 1.25, "cost": 5000},
	{"name_key": "GOLDEN_HALBERD", "base_atk": 1200, "atk_per_lv": 20, "aspd": 1.50, "cost": 7500},
	{"name_key": "MOUNTAIN_AXE", "base_atk": 1400, "atk_per_lv": 20, "aspd": 1.75, "cost": 10000},
]

# 每个里程碑(x9→x0)的锻造词条池
const WEAPON_FORGE_MILESTONES := {
	10: [
		{"stat": "card_refresh", "value": 2, "desc_key": "FORGE_CARD_REFRESH", "desc_args": ["2"]},
		{"stat": "move_speed", "value": 20, "desc_key": "FORGE_MOVE_SPD", "desc_args": ["20"]},
		{"stat": "hp_pct", "value": 0.10, "desc_key": "FORGE_HP_PCT", "desc_args": ["10"]},
	],
	20: [
		{"stat": "gold_per_sec", "value": 15, "desc_key": "FORGE_GOLD_SEC", "desc_args": ["15"]},
		{"stat": "str_flat", "value": 10, "desc_key": "FORGE_STR", "desc_args": ["10"]},
		{"stat": "hp_pct", "value": 0.10, "desc_key": "FORGE_HP_PCT", "desc_args": ["10"]},
	],
	30: [
		{"stat": "gold_per_sec", "value": 15, "desc_key": "FORGE_GOLD_SEC", "desc_args": ["15"]},
		{"stat": "agi_pct", "value": 0.10, "desc_key": "FORGE_AGI_PCT", "desc_args": ["10"]},
		{"stat": "atk_flat", "value": 100, "desc_key": "FORGE_ATK", "desc_args": ["100"]},
	],
	40: [
		{"stat": "move_speed", "value": 20, "desc_key": "FORGE_MOVE_SPD", "desc_args": ["20"]},
		{"stat": "atk_range", "value": 100, "desc_key": "FORGE_ATK", "desc_args": ["100"]},
		{"stat": "int_flat", "value": 10, "desc_key": "FORGE_INT", "desc_args": ["10"]},
	],
	50: [
		{"stat": "phys_crit", "value": 0.03, "desc_key": "FORGE_CRIT", "desc_args": ["3"]},
		{"stat": "spell_crit_mult", "value": 1, "desc_key": "FORGE_SPELL_CRIT", "desc_args": []},
		{"stat": "regen_flat", "value": 35, "desc_key": "FORGE_REGEN", "desc_args": ["35"]},
	],
	60: [
		{"stat": "str_flat", "value": 10, "desc_key": "FORGE_STR", "desc_args": ["10"]},
		{"stat": "extra_forge_2", "value": 2, "desc_key": "FORGE_EXTRA_PICK", "desc_args": ["2"]},
		{"stat": "aspd_pct", "value": 0.20, "desc_key": "FORGE_ASPD", "desc_args": ["20"]},
	],
	70: [
		{"stat": "gold_per_sec", "value": 15, "desc_key": "FORGE_GOLD_SEC", "desc_args": ["15"]},
		{"stat": "armor_pct", "value": 0.10, "desc_key": "FORGE_ARMOR_PCT", "desc_args": ["10"]},
		{"stat": "agi_pct", "value": 0.10, "desc_key": "FORGE_AGI_PCT", "desc_args": ["10"]},
	],
}

# === 盾牌段位配置 ===
const SHIELD_TIERS := [
	{"name_key": "WOODEN_SHIELD", "base_hp": 800, "hp_per_lv": 100, "regen": 20, "armor": 10, "cost": 500},
	{"name_key": "WHEEL_SHIELD", "base_hp": 1850, "hp_per_lv": 150, "regen": 30, "armor": 30, "cost": 1000},
	{"name_key": "ORANGE_WHEEL", "base_hp": 3400, "hp_per_lv": 200, "regen": 50, "armor": 50, "cost": 1500},
	{"name_key": "FUR_COAT", "base_hp": 6400, "hp_per_lv": 400, "regen": 75, "armor": 75, "cost": 2000},
	{"name_key": "MINK_COAT", "base_hp": 10500, "hp_per_lv": 500, "regen": 125, "armor": 100, "cost": 3000},
	{"name_key": "FULL_HELMET", "base_hp": 16000, "hp_per_lv": 600, "regen": 225, "armor": 125, "cost": 5000},
]

func init(game_mode) -> void:
	_gm = game_mode

# === 炮塔 ===

func get_turret_atk() -> float:
	if turret_grade != "":
		return TURRET_GRADES[turret_grade]["atk"]
	return 10.0 + turret_level * 5.0

func get_turret_all_stat() -> float:
	if turret_grade != "":
		return TURRET_GRADES[turret_grade]["all_stat"]
	return 1.0 + turret_level * 1.0

func _t(key: String, args: Array = []) -> String:
	if _gm and _gm.I18n:
		return _gm.I18n.t(key, args) if args.is_empty() else _gm.I18n.t(key, args)
	return key

func get_turret_display_name() -> String:
	if turret_grade != "":
		return _t("STORM_CANNON") + " " + turret_grade
	return _t("TURRET_LV", [str(turret_level)])

func upgrade_turret() -> bool:
	## 金币升级炮塔（Lv0-4），Lv5后进化
	if turret_level >= 5:
		return false
	var cost: int = 100 + turret_level * 50
	if EngineAPI.get_resource("gold") < cost:
		return false
	EngineAPI.subtract_resource("gold", cost)
	turret_level += 1
	if turret_level >= 5 and not weapon_unlocked:
		weapon_unlocked = true
		weapon_level = 0
		if _gm._combat_log_module:
			_gm._combat_log_module._add_log(_t("WEAPON_UNLOCK"), Color(0.3, 1, 0.5))
	_apply_equipment_stats()
	return true

func check_turret_evolution() -> void:
	## 按杀敌数自动进化（每帧检查）
	if turret_level < 5:
		return
	var kills: int = int(EngineAPI.get_resource("kills"))
	var next_grade := ""
	for grade in TURRET_GRADE_ORDER:
		if kills >= TURRET_GRADES[grade]["kills"]:
			next_grade = grade
	if next_grade != "" and next_grade != turret_grade:
		turret_grade = next_grade
		_apply_equipment_stats()
		if _gm._combat_log_module:
			_gm._combat_log_module._add_log(
				_t("TURRET_EVOLVE", [turret_grade]), Color(1, 0.85, 0.2)
			)

# === 武器 ===

func get_weapon_tier() -> int:
	@warning_ignore("INTEGER_DIVISION")
	return clampi(weapon_level / 10, 0, WEAPON_TIERS.size() - 1)

func get_weapon_config() -> Dictionary:
	if weapon_level < 0:
		return {}
	return WEAPON_TIERS[get_weapon_tier()]

func get_weapon_atk() -> float:
	if weapon_level < 0:
		return 0
	var tier := get_weapon_config()
	var tier_start: int = get_weapon_tier() * 10
	return tier["base_atk"] + (weapon_level - tier_start) * tier["atk_per_lv"]

func get_weapon_aspd() -> float:
	if weapon_level < 0:
		return 0
	return get_weapon_config()["aspd"]

func get_weapon_display_name() -> String:
	if weapon_level < 0:
		return _t("LOCKED")
	var cfg := get_weapon_config()
	var wname: String = _t(cfg.get("name_key", "WEAPON"))
	return "%s +%d" % [wname, weapon_level]

func get_weapon_upgrade_cost() -> int:
	if weapon_level < 0:
		return 0
	return get_weapon_config()["cost"]

func get_upgrade_success_rate() -> float:
	if weapon_level < 20:
		return 1.0
	@warning_ignore("INTEGER_DIVISION")
	var bracket: int = (weapon_level - 20) / 10
	return maxf(0.95 - bracket * 0.05, 0.50)

func upgrade_weapon() -> Dictionary:
	## 点击升级武器，返回 {success, milestone, forge_options}
	if weapon_level < 0:
		return {"success": false}
	var cost: int = get_weapon_upgrade_cost()
	if EngineAPI.get_resource("gold") < cost:
		return {"success": false, "reason": "not_enough_gold"}
	EngineAPI.subtract_resource("gold", cost)

	# 成功率判定
	var rate: float = get_upgrade_success_rate()
	if randf() > rate:
		if _gm._combat_log_module:
			_gm._combat_log_module._add_log(
				_t("UPGRADE_FAIL", [str(int(rate * 100))]), Color(1, 0.3, 0.3)
			)
		return {"success": false, "reason": "failed"}

	weapon_level += 1
	_apply_equipment_stats()

	var result := {"success": true, "level": weapon_level}

	# 里程碑检查（每10级整数）
	if weapon_level % 10 == 0 and weapon_level > 0:
		if weapon_level == 10 and not shield_unlocked:
			shield_unlocked = true
			shield_level = 0
			result["shield_unlocked"] = true
			if _gm._combat_log_module:
				_gm._combat_log_module._add_log(_t("SHIELD_UNLOCK"), Color(0.3, 1, 0.5))
		# 锻造词条三选一
		if WEAPON_FORGE_MILESTONES.has(weapon_level):
			result["forge_options"] = WEAPON_FORGE_MILESTONES[weapon_level]

	if _gm._combat_log_module:
		_gm._combat_log_module._add_log(
			_t("UPGRADE_SUCCESS", [get_weapon_display_name()]), Color(0.5, 0.8, 1)
		)
	return result

# === 盾牌 ===

func get_shield_tier() -> int:
	@warning_ignore("INTEGER_DIVISION")
	return clampi(shield_level / 10, 0, SHIELD_TIERS.size() - 1)

func get_shield_config() -> Dictionary:
	if shield_level < 0:
		return {}
	return SHIELD_TIERS[get_shield_tier()]

func get_shield_hp() -> float:
	if shield_level < 0:
		return 0
	var tier := get_shield_config()
	var tier_start: int = get_shield_tier() * 10
	return tier["base_hp"] + (shield_level - tier_start) * tier["hp_per_lv"]

func get_shield_regen() -> float:
	if shield_level < 0:
		return 0
	return get_shield_config()["regen"]

func get_shield_armor() -> float:
	if shield_level < 0:
		return 0
	return get_shield_config()["armor"]

func get_shield_display_name() -> String:
	if shield_level < 0:
		return _t("LOCKED")
	var cfg := get_shield_config()
	var sname: String = _t(cfg.get("name_key", "SHIELD"))
	return "%s +%d" % [sname, shield_level]

func get_shield_upgrade_cost() -> int:
	if shield_level < 0:
		return 0
	return get_shield_config()["cost"]

func upgrade_shield() -> Dictionary:
	if shield_level < 0:
		return {"success": false}
	var cost: int = get_shield_upgrade_cost()
	if EngineAPI.get_resource("gold") < cost:
		return {"success": false, "reason": "not_enough_gold"}
	EngineAPI.subtract_resource("gold", cost)

	var rate: float = get_upgrade_success_rate()
	if randf() > rate:
		if _gm._combat_log_module:
			_gm._combat_log_module._add_log(
				_t("UPGRADE_FAIL", [str(int(rate * 100))]), Color(1, 0.3, 0.3)
			)
		return {"success": false, "reason": "failed"}

	shield_level += 1
	_apply_equipment_stats()

	var result := {"success": true, "level": shield_level}
	# 盾牌里程碑（同样每10级词条三选一，复用武器词条池）
	if shield_level % 10 == 0 and shield_level > 0:
		if WEAPON_FORGE_MILESTONES.has(shield_level):
			result["forge_options"] = WEAPON_FORGE_MILESTONES[shield_level]

	if _gm._combat_log_module:
		_gm._combat_log_module._add_log(
			_t("UPGRADE_SUCCESS", [get_shield_display_name()]), Color(0.5, 0.8, 1)
		)
	return result

# === 锻造词条应用 ===

func apply_forge_bonus(bonus: Dictionary) -> void:
	## 应用选择的锻造词条（永久加成）
	forge_bonuses.append(bonus)
	var stat: String = bonus.get("stat", "")
	var value: float = bonus.get("value", 0)
	match stat:
		"gold_per_sec":
			var cur: float = float(EngineAPI.get_variable("hero_gold_per_sec", 0.0))
			EngineAPI.set_variable("hero_gold_per_sec", cur + value)
		"str_flat":
			var cur: float = float(EngineAPI.get_variable("hero_str_bonus", 0.0))
			EngineAPI.set_variable("hero_str_bonus", cur + value)
		"int_flat":
			var cur: float = float(EngineAPI.get_variable("hero_int_bonus", 0.0))
			EngineAPI.set_variable("hero_int_bonus", cur + value)
		"agi_pct":
			var cur: float = float(EngineAPI.get_variable("hero_agi_pct", 0.0))
			EngineAPI.set_variable("hero_agi_pct", cur + value)
		"hp_pct":
			var cur: float = float(EngineAPI.get_variable("hero_hp_pct", 0.0))
			EngineAPI.set_variable("hero_hp_pct", cur + value)
		"atk_flat":
			var cur: float = float(EngineAPI.get_variable("hero_atk_flat_bonus", 0.0))
			EngineAPI.set_variable("hero_atk_flat_bonus", cur + value)
		"move_speed":
			var cur: float = float(EngineAPI.get_variable("hero_move_speed_bonus", 0.0))
			EngineAPI.set_variable("hero_move_speed_bonus", cur + value)
		"phys_crit":
			var cur: float = float(EngineAPI.get_variable("hero_phys_crit", 0.005))
			EngineAPI.set_variable("hero_phys_crit", cur + value)
		"aspd_pct":
			var cur: float = float(EngineAPI.get_variable("hero_attack_speed_pct", 0.0))
			EngineAPI.set_variable("hero_attack_speed_pct", cur + value)
		"armor_pct":
			var cur: float = float(EngineAPI.get_variable("hero_armor_pct", 0.0))
			EngineAPI.set_variable("hero_armor_pct", cur + value)
		"regen_flat":
			var cur: float = float(EngineAPI.get_variable("hero_regen_flat_bonus", 0.0))
			EngineAPI.set_variable("hero_regen_flat_bonus", cur + value)
		"card_refresh":
			var cur: int = int(EngineAPI.get_variable("hero_card_refresh_bonus", 0))
			EngineAPI.set_variable("hero_card_refresh_bonus", cur + int(value))
	_apply_equipment_stats()
	if _gm._combat_log_module:
		_gm._combat_log_module._add_log(
			_t("FORGE_BONUS", [bonus.get("desc", stat)]), Color(1, 0.85, 0.3)
		)

# === 总属性计算 ===

func _apply_equipment_stats() -> void:
	## 将装备属性写入 hero 变量（供 stat_formula 使用）
	var total_atk: float = get_turret_atk() + get_weapon_atk()
	var total_aspd: float = get_weapon_aspd()
	var total_hp: float = get_shield_hp()
	var total_regen: float = get_shield_regen()
	var total_armor: float = get_shield_armor()
	var all_stat: float = get_turret_all_stat()

	EngineAPI.set_variable("equip_atk", total_atk)
	EngineAPI.set_variable("equip_aspd", total_aspd)
	EngineAPI.set_variable("equip_hp", total_hp)
	EngineAPI.set_variable("equip_regen", total_regen)
	EngineAPI.set_variable("equip_armor", total_armor)
	EngineAPI.set_variable("equip_all_stat", all_stat)

func process(_delta: float) -> void:
	## 每帧检查炮塔进化
	check_turret_evolution()
	# 每秒金币
	var gps: float = float(EngineAPI.get_variable("hero_gold_per_sec", 0.0))
	if gps > 0:
		EngineAPI.add_resource("gold", gps * _delta)

# === 锻造选择 UI ===

func show_forge_selection(options: Array, callback: Callable = Callable()) -> void:
	## 显示三选一锻造词条 UI
	var ui_layer: CanvasLayer = _gm.get_tree().current_scene.get_node_or_null("UI")
	if ui_layer == null:
		return
	if _forge_ui and is_instance_valid(_forge_ui):
		_forge_ui.queue_free()

	_forge_ui = Control.new()
	_forge_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(_forge_ui)

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_forge_ui.add_child(overlay)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.offset_left = -180
	vbox.offset_right = 180
	vbox.offset_top = -100
	vbox.offset_bottom = 100
	vbox.add_theme_constant_override("separation", 10)
	_forge_ui.add_child(vbox)

	var title := Label.new()
	title.text = _t("FORGE_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vbox.add_child(title)

	for opt in options:
		var btn := Button.new()
		var desc_key: String = opt.get("desc_key", "")
		var desc_args: Array = opt.get("desc_args", [])
		if desc_key != "":
			btn.text = _t(desc_key, desc_args)
		else:
			btn.text = opt.get("desc", "???")
		btn.custom_minimum_size = Vector2(0, 40)
		btn.add_theme_font_size_override("font_size", 14)
		var bonus: Dictionary = opt
		btn.pressed.connect(func() -> void:
			apply_forge_bonus(bonus)
			_forge_ui.queue_free()
			_forge_ui = null
			if callback.is_valid():
				callback.call()
		)
		vbox.add_child(btn)
