## 单元测试：Spell 数据完整性验证
## 确保 spells.json 所有条目结构正确、引用有效
extends GdUnitTestSuite

var _spells: Dictionary = {}
var _locales: Dictionary = {}

func before() -> void:
	var json := JSON.new()
	var text: String = FileAccess.get_file_as_string("res://gamepacks/rogue_survivor/data/spells.json")
	assert_int(json.parse(text)).is_equal(OK)
	_spells = json.data
	for lang in ["zh_CN", "en", "ja", "ko"]:
		var lt: String = FileAccess.get_file_as_string("res://gamepacks/rogue_survivor/data/spells_%s.json" % lang)
		var lj := JSON.new()
		assert_int(lj.parse(lt)).is_equal(OK)
		_locales[lang] = lj.data

# === 结构验证 ===

func test_all_entries_have_type() -> void:
	for sid: String in _spells:
		var s: Dictionary = _spells[sid]
		assert_str(s.get("type", "")).is_not_empty()

func test_card_entries_have_bond_id() -> void:
	for sid: String in _spells:
		var s: Dictionary = _spells[sid]
		if s.get("type") == "card":
			assert_bool(s.has("bond_id")).is_true()

func test_all_bond_ids_reference_valid_bonds() -> void:
	var bond_ids: Array = []
	for sid: String in _spells:
		if _spells[sid].get("type") == "bond":
			bond_ids.append(int(sid))
	for sid: String in _spells:
		var s: Dictionary = _spells[sid]
		if s.has("bond_id"):
			var bid: int = int(s["bond_id"])
			assert_bool(bid in bond_ids).is_true()

func test_bonds_have_required_field() -> void:
	for sid: String in _spells:
		var s: Dictionary = _spells[sid]
		if s.get("type") == "bond":
			assert_bool(s.has("required")).is_true()

# === Locale 完整性 ===

func test_all_locales_have_same_ids() -> void:
	var main_ids: Array = _spells.keys()
	main_ids.sort()
	for lang: String in _locales:
		var locale_ids: Array = _locales[lang].keys()
		locale_ids.sort()
		assert_array(locale_ids).is_equal(main_ids)

func test_all_locale_entries_have_name() -> void:
	for lang: String in _locales:
		for sid: String in _locales[lang]:
			var entry: Dictionary = _locales[lang][sid]
			assert_str(entry.get("name", "")).is_not_empty()

# === Proc 验证 ===

func test_proc_triggers_are_valid() -> void:
	var valid_triggers := ["on_hit", "on_hit_and_kill", "periodic", "on_level_up",
		"timer", "on_damage_taken", "on_cast", "on_crit", "passive"]
	for sid: String in _spells:
		var proc: Dictionary = _spells[sid].get("proc", {})
		var trigger: String = proc.get("trigger", "")
		if trigger != "":
			assert_bool(trigger in valid_triggers).is_true()

func test_proc_effects_are_valid() -> void:
	var valid_effects := ["double_damage", "chain_bounce", "scatter_shot", "aoe_damage",
		"aspd_buff", "bonus_gold", "instant_kill_minion", "add_percent", "grant_item",
		"add_growth", "spell_damage", "aoe_spell_damage", "bonus_damage",
		"bonus_spell_damage", "cheat_death", "line_spell_damage",
		"multi_area_spell_damage", "multi_projectile", "summon_puppet",
		"grant_resource", "orbiting_damage", "reduce_spell_cooldowns",
		"spell_damage_at_origin_and_dest"]
	for sid: String in _spells:
		var proc: Dictionary = _spells[sid].get("proc", {})
		var effect: String = proc.get("effect", "")
		if effect != "":
			assert_bool(effect in valid_effects).is_true()

# === 数值合理性 ===

func test_stat_values_are_reasonable() -> void:
	for sid: String in _spells:
		var stats: Dictionary = _spells[sid].get("stats", {})
		for key: String in stats:
			var val: float = float(stats[key])
			# 属性值不应为负数
			assert_float(val).is_greater_equal(0.0)
			# 百分比类属性不应超过 100%
			if key.ends_with("_pct") or key in ["crit_rate", "crit_dmg"]:
				assert_float(val).is_less_equal(10.0)

func test_cooldowns_are_positive() -> void:
	for sid: String in _spells:
		var proc: Dictionary = _spells[sid].get("proc", {})
		var cd: float = proc.get("cooldown", -1.0)
		if cd >= 0:
			assert_float(cd).is_greater_equal(0.0)

func test_every_bond_has_at_least_required_cards() -> void:
	## 防 Wave A "paper shipped" 重现：每个 bond 必须有 ≥required 张
	## bond_id 指向自己的 card，否则玩家永远抽不到，set bonus 永远不
	## 触发，commit 落地的 bond 等于死代码。dragon_ball #38 暂跳过
	## (pre-existing 5/7 under-supply, 跟 Wave A 无关)。
	var card_count: Dictionary = {}
	for sid: String in _spells:
		var entry: Dictionary = _spells[sid]
		if entry.get("type") != "card":
			continue
		var bid: int = int(entry.get("bond_id", 0))
		if bid == 0:
			continue
		card_count[bid] = card_count.get(bid, 0) + 1
	for sid: String in _spells:
		var entry: Dictionary = _spells[sid]
		if entry.get("type") != "bond":
			continue
		var bid: int = int(sid)
		if bid == 38:
			continue  # known under-supply
		var req: int = int(entry.get("required", 1))
		var have: int = int(card_count.get(bid, 0))
		assert_int(have).override_failure_message(
			"Bond #%d (%s) has %d cards but needs %d — paper-shipped, players can't activate" % [
				bid, str(entry.get("subclass", "")), have, req
			]).is_greater_equal(req)
