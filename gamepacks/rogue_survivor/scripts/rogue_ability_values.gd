## RogueAbilityValues — 能力值系统（查克拉/战力/武学）
## 每个能力值有阶梯效果，达到阈值时自动激活对应被动
extends RefCounted

var _gm
var _values: Dictionary = {}  # ability_id -> current_value
var _activated_tiers: Dictionary = {}  # ability_id -> Array of activated thresholds

# 阶梯定义
var _tier_definitions: Dictionary = {}  # ability_id -> Array[{threshold, effects}]

func init(game_mode) -> void:
	_gm = game_mode
	_init_definitions()

func _init_definitions() -> void:
	_tier_definitions = {
		"chakra": [
			{"threshold": 10, "effects": {"int": 30, "int_pct": 0.20}, "desc_key": "CHAKRA_T10"},
			{"threshold": 30, "effects": {"chakra_per_min": 1}, "desc_key": "CHAKRA_T30"},
			{"threshold": 50, "effects": {"mp": 300}, "desc_key": "CHAKRA_T50"},
			{"threshold": 80, "effects": {"skill_double_rate": 0.30, "int_pct": 0.30}, "desc_key": "CHAKRA_T80"},
			{"threshold": 120, "effects": {"skill_double_rate": 0.70, "int_pct": 0.50}, "desc_key": "CHAKRA_T120"},
			{"threshold": 150, "effects": {}, "desc_key": "CHAKRA_T150"},  # TODO: requires magic dust
		],
		"combat_power": [
			{"threshold": 10, "effects": {"atk": 300}, "desc_key": "POWER_T10"},
			{"threshold": 30, "effects": {"atk": 1000}, "desc_key": "POWER_T30"},
			{"threshold": 50, "effects": {"atk": 2000}, "desc_key": "POWER_T50"},
			{"threshold": 80, "effects": {"atk": 3000}, "desc_key": "POWER_T80"},
			{"threshold": 120, "effects": {"atk": 5000}, "desc_key": "POWER_T120"},
			{"threshold": 150, "effects": {}, "desc_key": "POWER_T150"},  # TODO: requires magic dust
		],
		"martial_arts": [
			{"threshold": 10, "effects": {"agi": 30, "agi_pct": 0.20}, "desc_key": "MARTIAL_T10"},
			{"threshold": 30, "effects": {"crit_rate": 0.05, "atk_pct": 0.35}, "desc_key": "MARTIAL_T30"},
			{"threshold": 50, "effects": {"aspd_pct": 1.0, "damage_pct": 0.25}, "desc_key": "MARTIAL_T50"},
			{"threshold": 80, "effects": {"agi_pct": 0.30, "skill_triple_rate": 0.10}, "desc_key": "MARTIAL_T80"},
			{"threshold": 120, "effects": {"crit_dmg": 1.0, "skill_triple_rate": 0.25}, "desc_key": "MARTIAL_T120"},
			{"threshold": 150, "effects": {}, "desc_key": "MARTIAL_T150"},  # TODO: requires magic dust
		],
	}
	for aid in _tier_definitions:
		_values[aid] = 0.0
		_activated_tiers[aid] = []

func add_value(ability_id: String, amount: float) -> void:
	if not _values.has(ability_id):
		_values[ability_id] = 0.0
		_activated_tiers[ability_id] = []
	_values[ability_id] += amount
	EngineAPI.set_variable("ability_" + ability_id, _values[ability_id])
	_check_tiers(ability_id)

func get_value(ability_id: String) -> float:
	return _values.get(ability_id, 0.0)

func _check_tiers(ability_id: String) -> void:
	var defs: Array = _tier_definitions.get(ability_id, [])
	var current: float = _values.get(ability_id, 0.0)
	var activated: Array = _activated_tiers.get(ability_id, [])
	for tier_def in defs:
		var threshold: int = tier_def.get("threshold", 0)
		if current >= threshold and threshold not in activated:
			activated.append(threshold)
			_activate_tier(ability_id, tier_def)

func _activate_tier(ability_id: String, tier_def: Dictionary) -> void:
	var effects: Dictionary = tier_def.get("effects", {})
	if _gm._card_sys:
		_gm._card_sys._apply_stats_to_hero(effects)
	# Announcement
	if _gm._hud_module:
		var I18n: Node = _gm.I18n
		var name_key: String = "ABILITY_" + ability_id.to_upper()
		var name_t: String = I18n.t(name_key) if I18n else ability_id
		var threshold: int = tier_def.get("threshold", 0)
		_gm._hud_module.add_announcement(
			"[b]%s Lv.%d[/b]" % [name_t, threshold],
			Color(1, 0.7, 0.2)
		)

func get_tooltip_text(ability_id: String) -> String:
	var defs: Array = _tier_definitions.get(ability_id, [])
	var current: float = _values.get(ability_id, 0.0)
	var activated: Array = _activated_tiers.get(ability_id, [])
	var I18n: Node = _gm.I18n if _gm else null
	var lines: Array[String] = []
	var name_key: String = "ABILITY_" + ability_id.to_upper()
	lines.append("[b]%s: %.0f[/b]" % [I18n.t(name_key) if I18n else ability_id, current])
	for tier_def in defs:
		var threshold: int = tier_def.get("threshold", 0)
		var is_active: bool = threshold in activated
		var marker: String = "✓" if is_active else "○"
		var desc_key: String = tier_def.get("desc_key", "")
		var desc: String = I18n.t(desc_key) if I18n and desc_key != "" else ">=%d" % threshold
		lines.append("%s [%d] %s" % [marker, threshold, desc])
	return "\n".join(lines)

func get_all_values() -> Dictionary:
	return _values.duplicate()
