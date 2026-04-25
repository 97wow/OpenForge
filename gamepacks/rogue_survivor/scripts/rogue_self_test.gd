## RogueSelfTest — 游戏内全自动战斗验证
## F12 触发：自动发卡→刷怪→等待战斗→收集伤害/proc/击杀数据→输出报告
## 不需要手动操作，全程自动
extends RefCounted

var _gm
var _results: Array[Dictionary] = []

# 战斗统计（通过事件收集）
var _damage_dealt: int = 0
var _kills: int = 0
var _procs_fired: int = 0
var _periodic_fired: int = 0
var _proc_names: Dictionary = {}
var _auras_applied: int = 0
var _cards_drawn: int = 0
var _connected: bool = false

func init(game_mode) -> void:
	_gm = game_mode

func run_all_tests() -> void:
	_results.clear()
	print("\n" + "=" .repeat(60))
	print("[SELF TEST] Phase 1: 静态验证")
	print("=" .repeat(60))
	_test_systems_exist()
	_test_hero()
	_test_stat_system()
	_test_spell_registration()
	_test_spell_damage_calc()
	_test_card_data()
	_test_all_proc_spells_registered()
	_test_no_legacy_code()
	_print_phase_result("Phase 1")

	# Phase 2: 实战验证
	print("\n" + "=" .repeat(60))
	print("[SELF TEST] Phase 2: 实战验证（自动发卡+刷怪+10秒战斗）")
	print("=" .repeat(60))
	_start_combat_test()

## Phase 2 由定时器驱动，10 秒后自动收集结果

func _start_combat_test() -> void:
	if not _gm.hero or not is_instance_valid(_gm.hero):
		_add("实战：英雄可用", false)
		_print_phase_result("Phase 2")
		return

	# 连接事件收集器
	_damage_dealt = 0
	_kills = 0
	_procs_fired = 0
	_periodic_fired = 0
	_auras_applied = 0
	_proc_names.clear()
	if not _connected:
		EventBus.connect_event("entity_damaged", _on_dmg)
		EventBus.connect_event("entity_killed", _on_kill)
		EventBus.connect_event("proc_triggered", _on_proc)
		EventBus.connect_event("spell_cast", _on_spell)
		EventBus.connect_event("aura_applied", _on_aura)
		_connected = true

	# 自动发满 8 张卡
	if _gm._card_sys and _gm._card_sys.held_cards.size() < 8:
		# 直接塞卡（跳过三选一UI），选有代表性的卡片覆盖各种 proc 类型
		var test_ids: Array[String] = ["13", "9", "15", "16", "14", "10", "66", "46"]
		var cs = _gm._card_sys
		for cid: String in test_ids:
			if cs.held_cards.size() >= 8:
				break
			if not cs._all_cards.has(cid):
				continue
			cs._on_card_picked(cid, cs._all_cards[cid].duplicate())
			_cards_drawn += 1
		print("[SELF TEST] 自动发 %d 张卡（直接入手）" % _cards_drawn)
		for card in cs.held_cards:
			var cid2: String = card.get("id", "?")
			var cname: String = cs.get_spell_name(cid2)
			var proc_info: String = card.get("data", {}).get("proc", {}).get("effect", "无proc")
			print("  卡片: %s (ID:%s) [%s]" % [cname, cid2, proc_info])

	# 刷一波怪在英雄旁边
	print("[SELF TEST] 刷 10 只怪在英雄附近...")
	var hero_pos: Vector3 = (_gm.hero as Node3D).global_position
	for _i in range(10):
		var offset := Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
		_gm.spawn("goblin", hero_pos + offset)

	# 10 秒后收集结果
	print("[SELF TEST] 等待 10 秒战斗...")
	_gm.get_tree().create_timer(10.0).timeout.connect(_finish_combat_test)

func _finish_combat_test() -> void:
	print("[SELF TEST] 战斗结束，收集结果...")
	_add("造成伤害 > 0", _damage_dealt > 0, "伤害事件=%d" % _damage_dealt)
	_add("击杀敌人 > 0", _kills > 0, "击杀=%d" % _kills)
	# 检查英雄身上已有的 aura（不依赖事件计数）
	var aura_mgr: Node = EngineAPI.get_system("aura")
	var hero_auras: int = aura_mgr.get_auras_on(_gm.hero).size() if aura_mgr else 0
	_add("Aura 生效", hero_auras > 0 or _auras_applied > 0, "当前aura=%d 新增=%d" % [hero_auras, _auras_applied])

	# Proc 验证：如果有 on_hit 类卡片，应该有 proc 触发
	var has_proc_card: bool = false
	if _gm._card_sys:
		for card in _gm._card_sys.held_cards:
			var trigger: String = card.get("data", {}).get("proc", {}).get("trigger", "")
			if trigger in ["on_hit", "on_crit", "on_kill"]:
				has_proc_card = true
				break
	if has_proc_card:
		_add("Proc 触发（有on_hit卡）", _procs_fired > 0, "触发=%d" % _procs_fired)
	else:
		_add("Proc 未触发（无on_hit卡）", true, "跳过")

	# 周期触发：铁斧或其他 periodic 卡
	var has_periodic: bool = false
	if _gm._card_sys:
		for card in _gm._card_sys.held_cards:
			if card.get("data", {}).get("proc", {}).get("trigger", "") == "periodic":
				has_periodic = true
				break
	# 铁斧是 skill 不是 card，总是有
	_add("铁斧/周期 触发", _periodic_fired > 0 or not has_periodic, "周期触发=%d" % _periodic_fired)

	# 英雄存活
	var alive: bool = _gm.hero != null and is_instance_valid(_gm.hero)
	if alive:
		var hc: Node = EngineAPI.get_component(_gm.hero, "health")
		if hc:
			_add("英雄存活", hc.current_hp > 0, "HP=%d/%d" % [int(hc.current_hp), int(hc.max_hp)])

	# Proc 明细
	if not _proc_names.is_empty():
		print("  Proc 明细:")
		for pname: String in _proc_names:
			print("    %s: %d 次" % [pname, _proc_names[pname]])

	_print_phase_result("Phase 2")
	_print_final_report()
	_show_hud_report()

# === 事件收集器 ===

func _on_dmg(_data: Dictionary) -> void:
	_damage_dealt += 1

func _on_kill(_data: Dictionary) -> void:
	_kills += 1

func _on_proc(data: Dictionary) -> void:
	_procs_fired += 1
	var spell: String = data.get("trigger_spell", "?")
	var card_id: String = spell.replace("card_", "").replace("_proc", "")
	_proc_names[card_id] = _proc_names.get(card_id, 0) + 1

func _on_spell(data: Dictionary) -> void:
	var sid: String = data.get("spell_id", "")
	if sid.ends_with("_proc"):
		_periodic_fired += 1

func _on_aura(_data: Dictionary) -> void:
	_auras_applied += 1

# === Phase 1: 静态验证 ===

func _test_systems_exist() -> void:
	for sys_name in ["stat", "spell", "aura", "proc", "vfx", "entity"]:
		_add("%s 系统存在" % sys_name, EngineAPI.get_system(sys_name) != null)

func _test_hero() -> void:
	var ok: bool = _gm.hero != null and is_instance_valid(_gm.hero)
	_add("英雄存在", ok)
	if not ok:
		return
	var atk: float = EngineAPI.get_total_stat(_gm.hero, "atk")
	var hc: Node = EngineAPI.get_component(_gm.hero, "health")
	_add("ATK > 0", atk > 0, "%.0f" % atk)
	_add("HP > 0", hc != null and hc.max_hp > 0, "%.0f" % (hc.max_hp if hc else 0))

func _test_stat_system() -> void:
	if not _gm.hero or not is_instance_valid(_gm.hero):
		return
	var before: float = EngineAPI.get_total_stat(_gm.hero, "atk")
	EngineAPI.add_green_stat(_gm.hero, "atk", 999.0)
	var after: float = EngineAPI.get_total_stat(_gm.hero, "atk")
	EngineAPI.remove_green_stat(_gm.hero, "atk", 999.0)
	var restored: float = EngineAPI.get_total_stat(_gm.hero, "atk")
	_add("绿字加算", after > before, "%.0f→%.0f" % [before, after])
	_add("绿字移除恢复", absf(restored - before) < 1.0, "%.0f→%.0f" % [after, restored])
	# 百分比
	EngineAPI.add_green_percent(_gm.hero, "atk", 1.0)
	var pct_after: float = EngineAPI.get_total_stat(_gm.hero, "atk")
	EngineAPI.remove_green_percent(_gm.hero, "atk", 1.0)
	_add("百分比加成", pct_after > before, "%.0f→%.0f(+100%%)" % [before, pct_after])

func _test_spell_registration() -> void:
	var ss: Node = EngineAPI.get_system("spell")
	if ss == null:
		return
	# 验证所有卡片的 spell 和 proc spell 都已注册
	var missing_spells: Array[String] = []
	var missing_procs: Array[String] = []
	if _gm._card_sys:
		for cid: String in _gm._card_sys._all_cards:
			var key: String = "card_%s" % cid
			if not ss.has_spell(key):
				# 没有 proc 也没有 stats 的卡片可能不注册
				var data: Dictionary = _gm._card_sys._all_cards[cid]
				if data.has("proc") or not data.get("stats", {}).is_empty():
					missing_spells.append(key)
			if _gm._card_sys._all_cards[cid].has("proc"):
				var proc_key: String = "card_%s_proc" % cid
				if not ss.has_spell(proc_key):
					missing_procs.append(proc_key)
		for sid: String in _gm._card_sys._all_skills:
			var data: Dictionary = _gm._card_sys._all_skills[sid]
			if data.has("proc") or not data.get("stats", {}).is_empty():
				var key: String = "card_%s" % sid
				if not ss.has_spell(key):
					missing_spells.append(key)
	_add("所有卡片 spell 已注册", missing_spells.is_empty(),
		"缺失: %s" % str(missing_spells) if not missing_spells.is_empty() else "全部OK")
	_add("所有 proc spell 已注册", missing_procs.is_empty(),
		"缺失: %s" % str(missing_procs) if not missing_procs.is_empty() else "全部OK")

func _test_spell_damage_calc() -> void:
	var ss: Node = EngineAPI.get_system("spell")
	if ss == null or not _gm.hero or not is_instance_valid(_gm.hero):
		return
	var atk: float = EngineAPI.get_total_stat(_gm.hero, "atk")
	# 测试每个 proc spell 的伤害是否 > 0（如果有 scaling）
	var zero_damage: Array[String] = []
	if _gm._card_sys:
		for source: Dictionary in [_gm._card_sys._all_cards, _gm._card_sys._all_skills]:
			for cid: String in source:
				var data: Dictionary = source[cid]
				if not data.has("proc"):
					continue
				var proc_key: String = "card_%s_proc" % cid
				if not ss.has_spell(proc_key):
					continue
				var proc_def: Dictionary = ss.get_spell(proc_key)
				var effects: Array = proc_def.get("effects", [])
				for eff: Dictionary in effects:
					if eff.get("type", "") == "SCHOOL_DAMAGE":
						var dmg: float = ss.calculate_value(_gm.hero, eff, proc_def)
						if dmg <= 0 and eff.get("scaling", {}).get("coefficient", 0) > 0:
							zero_damage.append(proc_key)
						break
	_add("所有 proc 伤害 > 0", zero_damage.is_empty(),
		"零伤害: %s" % str(zero_damage) if not zero_damage.is_empty() else "ATK=%.0f" % atk)

func _test_card_data() -> void:
	if _gm._card_sys == null:
		return
	_add("卡片数据 ≥50", _gm._card_sys._all_cards.size() >= 50,
		"卡=%d" % _gm._card_sys._all_cards.size())
	_add("羁绊数据 ≥10", _gm._card_sys._all_bonds.size() >= 10,
		"羁绊=%d" % _gm._card_sys._all_bonds.size())
	# Bond 引用完整性
	var bond_ids: Array = []
	for sid: String in _gm._card_sys._all_bonds:
		bond_ids.append(int(sid))
	var bad: int = 0
	for sid: String in _gm._card_sys._all_cards:
		var bid = _gm._card_sys._all_cards[sid].get("bond_id")
		if bid != null and int(bid) not in bond_ids:
			bad += 1
	_add("Bond 引用完整", bad == 0, "无效=%d" % bad)

func _test_all_proc_spells_registered() -> void:
	## 验证每种 proc effect 类型都有对应的 proc spell builder
	var ss: Node = EngineAPI.get_system("spell")
	if ss == null or _gm._card_sys == null:
		return
	var effect_types: Dictionary = {}
	for source: Dictionary in [_gm._card_sys._all_cards, _gm._card_sys._all_skills]:
		for cid: String in source:
			var eff: String = source[cid].get("proc", {}).get("effect", "")
			if eff != "":
				effect_types[eff] = effect_types.get(eff, 0) + 1
	var unhandled: Array[String] = []
	for eff: String in effect_types:
		# 找一个有这个 effect 的 card，检查其 proc spell 是否注册
		var found: bool = false
		for source2: Dictionary in [_gm._card_sys._all_cards, _gm._card_sys._all_skills]:
			for cid2: String in source2:
				if source2[cid2].get("proc", {}).get("effect", "") == eff:
					if ss.has_spell("card_%s_proc" % cid2):
						found = true
					break
			if found:
				break
		if not found:
			unhandled.append(eff)
	_add("所有 effect 类型已实现", unhandled.is_empty(),
		"未实现: %s" % str(unhandled) if not unhandled.is_empty() else "%d种" % effect_types.size())

func _test_no_legacy_code() -> void:
	# 检查废弃文件不存在
	_add("rogue_card_effects.gd 已删除",
		not FileAccess.file_exists("res://gamepacks/rogue_survivor/scripts/rogue_card_effects.gd"))
	# 检查 stat_system 无旧 modifier
	var stat_code: String = FileAccess.get_file_as_string("res://src/systems/stat_system.gd")
	_add("旧 modifier 系统已清除", not ("_modifiers" in stat_code))
	# 检查 spell_system 用 get_total_stat
	var spell_code: String = FileAccess.get_file_as_string("res://src/systems/spell_system.gd")
	_add("SpellSystem 用 get_total_stat", "get_total_stat" in spell_code)
	# 检查无 _final_crit_chance
	var combat_code: String = FileAccess.get_file_as_string("res://gamepacks/rogue_survivor/scripts/rogue_combat.gd")
	_add("旧暴击变量已清除", not ("_final_crit_chance" in combat_code))

# === 输出 ===

func _add(name: String, passed: bool, detail: String = "") -> void:
	_results.append({"name": name, "pass": passed, "detail": detail})
	var d: String = " (%s)" % detail if detail != "" else ""
	print("[SELF TEST] %s %s%s" % ["PASS" if passed else "FAIL", name, d])

func _print_phase_result(phase: String) -> void:
	var p: int = 0
	var f: int = 0
	for r: Dictionary in _results:
		if r["pass"]: p += 1
		else: f += 1
	print("[SELF TEST] %s: %d PASS / %d FAIL" % [phase, p, f])

func _print_final_report() -> void:
	var p: int = 0
	var f: int = 0
	var fails: Array[String] = []
	for r: Dictionary in _results:
		if r["pass"]:
			p += 1
		else:
			f += 1
			fails.append(r["name"])
	print("\n" + "=" .repeat(60))
	print("[SELF TEST] 最终结果: %d PASS / %d FAIL / %d 总计" % [p, f, _results.size()])
	if f > 0:
		print("[SELF TEST] 失败项:")
		for fn: String in fails:
			print("  ✗ %s" % fn)
	else:
		print("[SELF TEST] ✓ ALL %d TESTS PASSED" % p)
	print("=" .repeat(60))

func _show_hud_report() -> void:
	if _gm._hud_module == null:
		return
	var p: int = 0
	var f: int = 0
	for r: Dictionary in _results:
		if r["pass"]: p += 1
		else: f += 1
	var color: Color = Color(0.3, 1, 0.3) if f == 0 else Color(1, 0.3, 0.3)
	_gm._hud_module.add_announcement("[SELF TEST] %d/%d PASS" % [p, _results.size()], color)
	for r: Dictionary in _results:
		if not r["pass"]:
			_gm._hud_module.add_announcement("FAIL: %s" % r["name"], Color(1, 0.2, 0.2))
