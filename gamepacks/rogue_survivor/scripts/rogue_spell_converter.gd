## RogueSpellConverter — 将 spells.json 数据转换为 SpellSystem 可用的 spell 定义
## 从 rogue_card_system.gd 中提取，保持 card_system < 500 行
extends RefCounted

static func register_card_spells(all_cards: Dictionary) -> int:
	## 将所有卡片注册为 SpellSystem spell，返回注册数量
	var spell_sys: Node = EngineAPI.get_system("spell")
	if spell_sys == null:
		push_warning("[SpellConverter] SpellSystem not ready")
		return 0
	var count: int = 0
	for card_id: String in all_cards:
		var data: Dictionary = all_cards[card_id]
		var spell_def: Dictionary = convert_to_spell_def(card_id, data)
		if spell_def.get("effects", []).is_empty():
			continue
		spell_sys.register_spell("card_%s" % card_id, spell_def)
		if data.has("proc"):
			var proc_spell: Dictionary = build_proc_spell(card_id, data)
			if not proc_spell.is_empty():
				spell_sys.register_spell("card_%s_proc" % card_id, proc_spell)
		count += 1
	return count

static func convert_to_spell_def(card_id: String, data: Dictionary) -> Dictionary:
	## 将 spells.json 的 proc 格式转换为 SpellSystem spell 定义
	var proc: Dictionary = data.get("proc", {})
	var trigger: String = proc.get("trigger", "")
	var effects: Array = []

	match trigger:
		"on_hit":
			effects.append({
				"type": "APPLY_AURA", "aura": "PROC_TRIGGER_SPELL",
				"duration": -1.0, "trigger_spell": "card_%s_proc" % card_id,
				"proc": {"flags": ["on_hit"], "chance": proc.get("chance", 1.0) * 100.0, "cooldown": proc.get("cooldown", 0.5)},
				"target": {"category": "SELF"},
			})
		"on_hit_and_kill":
			effects.append({
				"type": "APPLY_AURA", "aura": "PROC_TRIGGER_SPELL",
				"duration": -1.0, "trigger_spell": "card_%s_proc" % card_id,
				"proc": {"flags": ["on_hit", "on_kill"], "chance": 100.0, "cooldown": 0.0},
				"target": {"category": "SELF"},
			})
		"periodic":
			var periodic_effect: Dictionary = {
				"type": "APPLY_AURA", "aura": "PERIODIC_TRIGGER_SPELL",
				"duration": -1.0, "period": proc.get("interval", 5.0),
				"trigger_spell": "card_%s_proc" % card_id,
				"target": {"category": "SELF"},
			}
			# 可选概率（如铁斧 15% 概率触发）
			var tick_chance: float = proc.get("chance_aoe", proc.get("chance", 0.0))
			if tick_chance > 0 and tick_chance < 1.0:
				periodic_effect["chance"] = tick_chance
			effects.append(periodic_effect)
		"on_level_up":
			effects.append({
				"type": "APPLY_AURA", "aura": "PROC_TRIGGER_SPELL",
				"duration": -1.0, "trigger_spell": "card_%s_proc" % card_id,
				"proc": {"flags": ["on_level_up"], "chance": 100.0, "cooldown": 0.0},
				"target": {"category": "SELF"},
			})
		"timer":
			var delay: float = proc.get("delay", 300.0)
			effects.append({
				"type": "APPLY_AURA", "aura": "PERIODIC_TRIGGER_SPELL",
				"duration": delay + 1.0, "period": delay,
				"trigger_spell": "card_%s_proc" % card_id,
				"target": {"category": "SELF"},
			})
		"on_damage_taken":
			# 受到伤害时触发（佛之战国）
			effects.append({
				"type": "APPLY_AURA", "aura": "PROC_TRIGGER_SPELL",
				"duration": -1.0, "trigger_spell": "card_%s_proc" % card_id,
				"proc": {"flags": ["take_melee", "take_ranged"], "chance": 100.0, "cooldown": proc.get("cooldown", 180.0)},
				"target": {"category": "SELF"},
			})
		"on_cast":
			# 施法时触发（光光黄猿 - 闪现时伤害）
			effects.append({
				"type": "APPLY_AURA", "aura": "PROC_TRIGGER_SPELL",
				"duration": -1.0, "trigger_spell": "card_%s_proc" % card_id,
				"proc": {"flags": ["on_spell_cast"], "chance": 100.0, "cooldown": proc.get("cooldown", 0.0)},
				"target": {"category": "SELF"},
			})
		"passive":
			# 被动效果：获取时直接执行一次 proc spell（不是 aura）
			pass  # proc spell 在 _cast_card_spell 时直接 cast

	# stats → MOD_STAT aura / ADD_RESOURCE
	var stats: Dictionary = data.get("stats", {})
	for stat_key: String in stats:
		var value: float = float(stats[stat_key])
		if stat_key in ["gold", "wood", "gold_per_sec"]:
			effects.append({
				"type": "ADD_RESOURCE" if stat_key != "gold_per_sec" else "SET_VARIABLE",
				"resource": stat_key if stat_key != "gold_per_sec" else "",
				"key": "hero_gold_per_sec" if stat_key == "gold_per_sec" else "",
				"base_points": value, "mode": "add",
				"target": {"category": "SELF"},
			})
		elif stat_key.ends_with("_pct"):
			var base_stat: String = stat_key.trim_suffix("_pct")
			# 区分属性百分比 vs 倍率百分比
			# 属性百分比（有非零 white_base）：用 percent 乘算
			# 倍率百分比（base=0 的倍率）：用 flat 加算（它们本身就是倍率）
			var rate_stats := ["aspd", "boss_dmg", "damage", "splash", "crit_rate", "crit_dmg", "move_speed", "armor"]
			var mod: String = "flat" if base_stat in rate_stats else "percent"
			effects.append({
				"type": "APPLY_AURA", "aura": "MOD_STAT",
				"misc_value": base_stat,
				"base_points": value, "mod_type": mod,
				"duration": -1.0, "target": {"category": "SELF"},
			})
		elif stat_key == "all_stat":
			for s in ["str", "agi", "int"]:
				effects.append({
					"type": "APPLY_AURA", "aura": "MOD_STAT",
					"misc_value": s, "base_points": value,
					"mod_type": "flat", "duration": -1.0,
					"target": {"category": "SELF"},
				})
		else:
			effects.append({
				"type": "APPLY_AURA", "aura": "MOD_STAT",
				"misc_value": stat_key, "base_points": value,
				"mod_type": "flat", "duration": -1.0,
				"target": {"category": "SELF"},
			})

	return {"id": "card_%s" % card_id, "effects": effects, "school": "physical"}

static func build_proc_spell(card_id: String, data: Dictionary) -> Dictionary:
	## 构建 proc spell（aura 触发时实际执行的效果）
	var proc: Dictionary = data.get("proc", {})
	var effect_type: String = proc.get("effect", "")
	var effects: Array = []

	match effect_type:
		"double_damage":
			effects.append({"type": "SCHOOL_DAMAGE", "base_points": 0, "scaling": {"stat": "atk", "coefficient": 1.0}, "target": {"category": "DEFAULT", "check": "ENEMY"}})
		"chain_bounce":
			effects.append({"type": "SCHOOL_DAMAGE", "base_points": 0, "scaling": {"stat": "atk", "coefficient": proc.get("damage_pct", 1.0)}, "target": {"category": "CHAIN", "check": "ENEMY", "chain_targets": proc.get("count", 3), "chain_range": 3.0, "reference": "TARGET"}})
		"scatter_shot":
			effects.append({"type": "SCHOOL_DAMAGE", "base_points": 0, "scaling": {"stat": "atk", "coefficient": proc.get("damage_pct", 1.0)}, "target": {"category": "AREA", "check": "ENEMY", "radius": 3.0, "max_targets": proc.get("count", 3), "reference": "TARGET"}})
		"aoe_damage":
			effects.append({"type": "SCHOOL_DAMAGE", "base_points": 0, "scaling": {"stat": "atk", "coefficient": proc.get("damage_pct", 1.0)}, "target": {"category": "AREA", "check": "ENEMY", "radius": proc.get("range", 3.5), "max_targets": 10, "reference": "CASTER"}})
		"aspd_buff":
			effects.append({"type": "APPLY_AURA", "aura": "MOD_STAT", "duration": proc.get("duration", 3.0), "misc_value": "aspd", "mod_type": "percent", "base_points": proc.get("value", 5.0), "target": {"category": "SELF"}})
		"bonus_gold":
			effects.append({"type": "ADD_RESOURCE", "resource": "gold", "base_points": float(proc.get("hit_gold", 1)), "target": {"category": "SELF"}})
		"instant_kill_minion":
			var bonus: int = proc.get("bonus_mult", 5)
			effects.append({"type": "INSTANT_KILL", "target": {"category": "PROC_TARGET", "check": "ENEMY"}, "filter": {"exclude_tags": ["boss"]}, "bonus_gold": 4 * bonus, "bonus_xp": 5 * bonus})
		"add_percent":
			effects.append({"type": "ADD_GREEN_PERCENT", "stat": proc.get("stat", ""), "base_points": proc.get("value", 0.001), "target": {"category": "SELF"}})
		"grant_item":
			effects.append({"type": "ADD_RESOURCE", "resource": "devour_pill", "base_points": 1.0, "target": {"category": "SELF"}})
		"add_growth":
			var growth_stats: Dictionary = proc.get("stats", {})
			for gs: String in growth_stats:
				effects.append({"type": "ADD_GREEN_STAT", "stat": gs, "base_points": float(growth_stats[gs]), "target": {"category": "SELF"}})
		# === P5 新增 effect 类型 ===
		"spell_damage", "aoe_spell_damage":
			# 单体/AOE 法术伤害（青雉/赤犬/神杀枪/冰轮丸/郭靖）
			var radius: float = proc.get("range", 3.5 if effect_type == "aoe_spell_damage" else 0.0)
			var tgt := {"category": "DEFAULT", "check": "ENEMY"}
			if radius > 0:
				tgt = {"category": "AREA", "check": "ENEMY", "radius": radius, "max_targets": proc.get("count", 6), "reference": "TARGET"}
			elif proc.get("count", 1) > 1:
				tgt = {"category": "AREA", "check": "ENEMY", "radius": 3.5, "max_targets": proc.get("count", 3), "reference": "TARGET"}
			effects.append({"type": "SCHOOL_DAMAGE", "school": 2, "base_points": 0, "scaling": {"stat": "atk", "coefficient": proc.get("damage_pct", 1.0)}, "target": tgt})
		"bonus_damage", "bonus_spell_damage":
			# 攻击附带额外伤害（四皇系列/黄蓉）
			var school: int = 2 if effect_type == "bonus_spell_damage" else 0
			var base: float = proc.get("base_damage", 200)
			var stat: String = proc.get("scaling_stat", "str")
			var coef: float = proc.get("scaling_coef", 0.3)
			effects.append({"type": "SCHOOL_DAMAGE", "school": school, "base_points": base, "scaling": {"stat": stat, "coefficient": coef}, "target": {"category": "DEFAULT", "check": "ENEMY"}})
		"cheat_death":
			# 佛之战国：免疫致死 + 满血
			effects.append({"type": "APPLY_AURA", "aura": "CHEAT_DEATH", "duration": -1.0, "target": {"category": "SELF"}})
		"line_spell_damage":
			# 斩月：直线伤害
			effects.append({"type": "SCHOOL_DAMAGE", "school": 2, "base_points": 0, "scaling": {"stat": "atk", "coefficient": proc.get("damage_pct", 1.2)}, "target": {"category": "AREA", "check": "ENEMY", "radius": 6.0, "max_targets": 8, "reference": "TARGET"}})
		"multi_area_spell_damage":
			# 雷神索尔：多区域伤害
			var count: int = proc.get("area_count", 3)
			for _i in range(count):
				effects.append({"type": "SCHOOL_DAMAGE", "school": 2, "base_points": 0, "scaling": {"stat": "atk", "coefficient": proc.get("damage_pct", 2.4)}, "target": {"category": "AREA", "check": "ENEMY", "radius": 2.5, "max_targets": 4, "reference": "RANDOM_ENEMY"}})
		"multi_projectile":
			# 流刃若火：多发投射物
			var proj_count: int = proc.get("count", 3)
			for _i in range(proj_count):
				effects.append({"type": "SCHOOL_DAMAGE", "school": 2, "base_points": 0, "scaling": {"stat": "atk", "coefficient": proc.get("damage_pct", 1.35)}, "target": {"category": "DEFAULT", "check": "ENEMY"}})
		"summon_puppet":
			# 赤砂傀儡师：召唤傀儡
			effects.append({"type": "SUMMON", "summon_id": "shadow", "duration": 15.0, "target": {"category": "SELF"}})
		"grant_resource":
			# 晓组织财务：给资源
			var res: String = proc.get("resource", "wood")
			effects.append({"type": "ADD_RESOURCE", "resource": res, "base_points": proc.get("amount", 210), "target": {"category": "SELF"}})
		"orbiting_damage":
			# 金轮法王：环绕伤害（用周期 AOE 近似）
			effects.append({"type": "SCHOOL_DAMAGE", "base_points": 0, "scaling": {"stat": "atk", "coefficient": proc.get("damage_pct", 3.0)}, "target": {"category": "AREA", "check": "ENEMY", "radius": 2.0, "max_targets": 3, "reference": "CASTER"}})
		"reduce_spell_cooldowns":
			# 镜花水月：减少其他技能 CD（通过变量标记）
			effects.append({"type": "SET_VARIABLE", "key": "hero_spell_cd_reduction", "base_points": proc.get("reduction", 2.5), "mode": "add", "target": {"category": "SELF"}})
		"spell_damage_at_origin_and_dest":
			# 光光黄猿：起点+终点双重伤害
			effects.append({"type": "SCHOOL_DAMAGE", "school": 2, "base_points": 0, "scaling": {"stat": "atk", "coefficient": proc.get("damage_pct", 1.75)}, "target": {"category": "AREA", "check": "ENEMY", "radius": 3.0, "max_targets": 6, "reference": "CASTER"}})
		_:
			return {}

	if effects.is_empty():
		return {}
	return {"id": "card_%s_proc" % card_id, "effects": effects, "school": "physical", "_is_proc": true}
